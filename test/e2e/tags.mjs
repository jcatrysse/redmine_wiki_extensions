// Tags: the tag fields on the wiki edit form (dropdown + free text +
// autocomplete), {{tags}}, the tag page, tagcloud/taglist/taggedpages, and
// the failure paths (tag of another project, markup in a tag name).
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('tags');
const W = '/projects/e2e-project/wiki';
const dialogs = [];

await t.login('manager');
t.page.on('dialog', d => { dialogs.push(d.message()); d.dismiss(); });

// start from the seeded tags of Tagged_two ("approved" only), whatever an earlier run left
async function setTags(page, first, rest = []) {
  await t.go(`${W}/${page}/edit`);
  const sel = t.page.locator('select[name="extension[tags][0]"]');
  if (!(await sel.locator(`option[value="${first}"]`).count())) throw new Error(`no option ${first}`);
  await sel.selectOption(first);
  for (let i = 1; i < 4; i++) await t.page.locator(`input[name="extension[tags][${i}]"]`).fill(rest[i - 1] || '');
  await t.page.locator('#wiki_form input[type=submit]').first().click();
  await t.page.waitForLoadState('load');
}
await setTags('Tagged_two', 'approved');

// Tagged_one has "alpha" and "approved"; "alpha" sorts first but is no dropdown option
await t.go(`${W}/Tagged_one/edit`);
const select = t.page.locator('select[name="extension[tags][0]"]');
assert.equal(await select.inputValue(), 'alpha', 'the first tag stays selected');
assert.equal(await t.page.locator('input[name="extension[tags][1]"]').inputValue(), 'approved');
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded();
await t.shot('edit-first-tag-kept', 'Edit form of Tagged_one: the dropdown keeps "alpha" (not an option; it used to fall back to blank and be deleted on save), "approved" in the next field');
await t.page.locator('#wiki_form input[type=submit][name=commit], #wiki_form input[type=submit]').first().click();
await t.page.waitForLoadState('load');
await t.go(`${W}/Tagged_one`);
const tags1 = await t.page.locator('ul.wikiext-tags li').allInnerTexts();
assert.deepEqual(tags1.sort(), ['alpha', 'approved'], 'saving without changes keeps both tags');
await t.shot('saved-tags-kept', '{{tags}} after saving the form unchanged: alpha and approved are both still there');
t.check('save Tagged_one');

// Tagged_two: dropdown option + a new free-text tag with autocomplete
await t.go(`${W}/Tagged_two/edit`);
assert.equal(await select.inputValue(), 'approved');
const options = await select.locator('option').allInnerTexts();
assert.deepEqual(options, ['', 'draft', 'in-review', 'approved', 'archived', 'obsolete', 'needs-update'], 'default dropdown options');
await select.selectOption('in-review');
const free = t.page.locator('input[name="extension[tags][1]"]');
await free.click();
await free.pressSequentially('al', { delay: 80 });
const suggestion = t.page.locator('ul.ui-autocomplete li', { hasText: 'alpha' });
await suggestion.waitFor({ state: 'visible', timeout: 5000 });
await t.shot('autocomplete', 'Typing "al" in a free tag field suggests the existing tag "alpha" (jQuery UI autocomplete); the dropdown is set to "in-review"');
await free.fill('beta');
await t.page.locator('#wiki_form input[type=submit]').first().click();
await t.page.waitForLoadState('load');
await t.go(`${W}/Tagged_two`);
assert.deepEqual((await t.page.locator('ul.wikiext-tags li').allInnerTexts()).sort(), ['beta', 'in-review']);
await t.shot('saved-new-tags', 'Tagged_two now carries "in-review" (dropdown) and "beta" (free text)');
t.check('save Tagged_two');

// tag page from a {{tags}} link
await t.page.locator('ul.wikiext-tags a', { hasText: 'beta' }).click();
await t.page.waitForLoadState('load');
assert.match(t.page.url(), /\/projects\/e2e-project\/wiki_extensions\/tag\?tag_id=\d+/);
assert.deepEqual(await t.page.locator('#content li a').allInnerTexts(), ['Tagged two']);
await t.shot('tag-page', 'The tag page of "beta" lists the page that carries it');
t.check('tag page');

// tag index macros
await t.go(`${W}/Tag_index`);
const idx = t.page.locator('.wiki.wiki-page');
assert.ok(await idx.locator('a[class^="tag_level"]').count() >= 2, 'tagcloud');
assert.match(await idx.innerText(), /alpha\(1\)/);
assert.match(await idx.innerText(), /approved\(\d\)/);
assert.ok(await idx.locator('ul.wikiext-taggedpages a', { hasText: 'Tagged one' }).count() >= 1, 'taggedpages(approved)');
await t.shot('tag-index', 'tagcloud, taglist, taglist_commas, taglist_bullets and taggedpages (OR and AND) on one page');

// put Tagged_two back to "approved" so the scenario can run again
await setTags('Tagged_two', 'approved');

// markup in a tag name stays text (the Unsafe page carries one)
await t.go(`${W}/Unsafe/edit`);
await t.page.waitForTimeout(500);
const evil = t.page.locator('input[name="extension[tags][1]"]');
assert.match(await evil.inputValue(), /^x" onfocus="alert\('tag'\)" autofocus="$/);
assert.equal(await t.page.locator('input[onfocus]').count(), 0);
await evil.focus();
await t.page.waitForTimeout(300);
assert.deepEqual(dialogs, [], 'no script ran');
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded();
await t.shot('tag-name-escaped', 'A tag named x" onfocus="alert(\'tag\')" autofocus=" is shown as text in its field; focusing it runs nothing (it used to become an onfocus handler)');

// --- reporter: may view tags, may not edit pages
await t.login('reporter');
await t.go(`${W}/Tagged_one`);
assert.equal(await t.page.locator('ul.wikiext-tags li').count(), 2);
await t.page.locator('ul.wikiext-tags a', { hasText: 'approved' }).click();
await t.page.waitForLoadState('load');
assert.ok(await t.page.locator('#content li a', { hasText: 'Tagged one' }).count() === 1);
await t.shot('reporter-tag-page', 'reporter: tags and the tag page are visible (show_wiki_tags is a public permission)');
await t.go(`${W}/Tagged_one/edit`, { status: 403 });

// a tag of e2e-private through the e2e-project URL: never listed
const found = [];
for (let id = 1; id <= 12; id++) {
  const r = await t.page.request.get(`${t.BASE}/projects/e2e-project/wiki_extensions/tag?tag_id=${id}`);
  const body = await r.text();
  assert.ok(!body.includes('/projects/e2e-private/wiki/Secret'), `tag ${id} must not list the private page`);
  found.push(`${id}:${r.status()}`);
}
assert.ok(found.some(f => f.endsWith(':404')), 'tags of other projects answer 404');
await t.go(`${W}/Tag_index`);
await t.shot('reporter-tag-ids', `reporter, GET /projects/e2e-project/wiki_extensions/tag?tag_id=1..12: ${found.join(' ')}; 404 for tags of other projects, the private page is never listed`);

// --- anonymous and outsider
await t.anonymous();
await t.go('/projects/e2e-private/wiki_extensions/tag?tag_id=1'); // redirected to the login form
assert.match(t.page.url(), /\/login\?back_url=/);
await t.login('outsider');
await t.go('/projects/e2e-private/wiki_extensions/tag?tag_id=1', { status: 403 });
await t.shot('outsider-private-tag', 'outsider: the tag page of the private project is refused (403); anonymous is sent to the login page');

await t.done();
