// "Before" pictures: the branch GEOxyz runs today (Redmine-5.1 @ e0b64b3) on
// Redmine 5.1, for every behaviour the Redmine 7 migration changed. It records
// what happens instead of asserting. Run against a 5.1 server:
//   RMP_URL=http://127.0.0.1:3002 RMP_E2E_OUT=docs/e2e/before node test/e2e_before/redmine51.mjs
import { e2e } from '../../.codex/e2e/lib.mjs';

const t = await e2e('before');
const W = '/projects/e2e-project/wiki';
const any = { js: [''], requests: [''] };
const dialogs = [];
const note = [];
const watchDialogs = () => t.page.on('dialog', d => { dialogs.push(d.message()); d.dismiss().catch(() => {}); });

await t.login('manager'); watchDialogs();

// with a StyleSheet page every wiki page of the project raised (fixed by deb638a);
// run with RMP_BEFORE_STEP=stylesheet first, then remove the StyleSheet pages
if (process.env.RMP_BEFORE_STEP === 'stylesheet') {
  await t.go(`${W}/Vote`, { status: 500, allow: any });
  await t.shot('stylesheet-500', 'Before: e2e-project has a StyleSheet wiki page, so every wiki page answers 500 (undefined method wiki_extensions_stylesheet_path, GEOxyz ff3dba7)');
  t.problems.length = 0;
  await t.done();
  process.exit(0);
}

// vote: the macro sends GET, the route accepts POST only
await t.go(`${W}/Vote`, { allow: any });
const resp = t.page.waitForResponse(r => r.url().includes('/wiki_extensions/vote'), { timeout: 5000 }).catch(() => null);
await t.page.locator('span.wikiext-vote a').first().click();
const r = await resp;
note.push(`vote click: ${r ? `${r.request().method()} -> HTTP ${r.status()}` : 'no request'}`);
await t.page.waitForTimeout(500);
await t.shot('vote', `Before: clicking "I like it" sends ${r ? r.request().method() : '?'} and gets HTTP ${r ? r.status() : '?'}; the count does not change`);
t.check('vote', any);

// count: does a reload in the same session count again?
await t.go(`${W}/Macros`, { allow: any });
const v1 = (await t.page.locator('.wiki.wiki-page').innerText()).match(/views: (\d+)/)?.[1];
await t.go(`${W}/Macros`, { allow: any });
const v2 = (await t.page.locator('.wiki.wiki-page').innerText()).match(/views: (\d+)/)?.[1];
note.push(`count on reload: ${v1} -> ${v2}`);

// comment form without toolbar
const errs = [];
t.page.on('pageerror', e => errs.push(e.message));
await t.go(`${W}/Comments`, { allow: any });
await t.page.getByRole('link', { name: 'Add a comment' }).first().click();
await t.page.waitForTimeout(500);
note.push(`comment form toolbar elements: ${await t.page.locator('div[id^="add_comment_form_div"] .jstElements').count()}, JS errors: ${errs.join(' | ') || 'none'}`);
await t.shot('comment-form', `Before: the comment form from {{comment_form}} (toolbar elements: ${await t.page.locator('div[id^="add_comment_form_div"] .jstElements').count()}; JS: ${errs[0] || 'no error'})`);
const del = t.page.locator('ul.IsRoot a.icon-del').first();
note.push(`delete link: href=${await del.getAttribute('href')} data-method=${await del.getAttribute('data-method')} data-confirm=${await del.getAttribute('data-confirm')} confirm=${await del.getAttribute('confirm')}`);
t.check('comments', any);

// first tag not in the dropdown
await t.go(`${W}/Tagged_one/edit`, { allow: any });
const sel = await t.page.locator('select[name="extension[tags][0]"]').inputValue().catch(() => '?');
note.push(`Tagged_one edit (tags alpha, approved): dropdown value "${sel}", field 1 "${await t.page.locator('input[name="extension[tags][1]"]').inputValue().catch(() => '?')}"`);
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded().catch(() => {});
await t.shot('first-tag', `Before: Tagged_one carries "alpha" and "approved"; the dropdown shows "${sel}" (blank: saving would delete "alpha")`);

// tag name with markup
dialogs.length = 0;
await t.go(`${W}/Unsafe/edit`, { allow: any });
await t.page.waitForTimeout(800);
note.push(`Unsafe edit: input[onfocus] = ${await t.page.locator('input[onfocus]').count()}, dialogs: ${dialogs.join(' | ') || 'none'}`);
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded().catch(() => {});
await t.shot('tag-xss', `Before: the tag x" onfocus="alert('tag')" autofocus=" becomes attributes of its input (onfocus handlers: ${await t.page.locator('input[onfocus]').count()}; dialogs: ${dialogs.join(', ') || 'none'})`);
t.check('tag xss', any);

// stray Tab#0 after a forward_wiki_page without menu_id
await t.go('/projects/e2e-project/wiki_extensions/forward_wiki_page', { status: 302, allow: any }).catch(() => {});
note.push(`forward_wiki_page without menu_id: landed on ${t.page.url().replace(t.BASE, '')}`);
await t.go('/projects/e2e-project/settings/wiki_extensions', { allow: any });
const labels = await t.page.locator('#wiki_extensions_settings .wiki-menu-entry > b').allInnerTexts().catch(() => []);
note.push(`settings tabs: ${labels.join(', ')}`);
await t.shot('settings-tabs', `Before: after one GET of forward_wiki_page without menu_id the settings list ${labels.join(', ')}`);

// reporter: private project leaks and stored XSS
await t.login('reporter'); watchDialogs();
await t.go(`${W}/Leaks`, { allow: any });
const leak = await t.page.locator('.wiki.wiki-page').innerText();
note.push(`Leaks as reporter: ${leak.replace(/\s+/g, ' ').slice(0, 300)}`);
await t.shot('leaks', 'Before: reporter (no member of e2e-private) sees the private project name, a link to its Secret page, its update time and its tagged page');
dialogs.length = 0;
await t.go(`${W}/Unsafe`, { allow: any });
await t.page.waitForTimeout(1500);
note.push(`Unsafe view as reporter: img[onerror] ${await t.page.locator('img[onerror]').count()}, iframe[onload] ${await t.page.locator('iframe[onload]').count()}, dialogs: ${dialogs.join(' | ') || 'none'}`);
await t.shot('macro-xss', `Before: the footnote word and the iframe width run script for the reader (dialogs: ${dialogs.join(', ') || 'none'})`);
await t.go('/projects/e2e-project/wiki_extensions/destroy_comment?comment_id=999999', { allow: any, status: 404 }).catch(() => {});
note.push(`GET destroy_comment as reporter: HTTP ${await t.page.evaluate(() => document.title)}`);
t.check('reporter', any);

console.log(note.join('\n'));
import('node:fs').then(fs => fs.writeFileSync(`${process.env.RMP_E2E_OUT || 'docs/e2e'}/before-notes.txt`, note.join('\n') + '\n'));
t.problems.length = 0; // a picture of the old behaviour is the point, not a failure
await t.done();
