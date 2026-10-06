// Display macros on a CommonMark wiki page, as the users that matter, and the
// failure paths: invalid arguments render a macro error, not a 500.
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('macros');
const P = '/projects/e2e-project/wiki';

await t.login('manager');
await t.go(`${P}/Macros`, { allow: { requests: ['/missing.mp4'] } }); // the video URL is a placeholder
const w = t.page.locator('.wiki.wiki-page');
assert.equal(await w.locator('.wiki_ext_new_date').count(), 3, 'three {{new}} dates');
assert.match(await w.locator('.wiki_ext_new_mark').first().innerText(), /New!!!/);
assert.equal(await w.locator('a[href="/projects/e2e-project"]', { hasText: 'alias for the project' }).count(), 1);
assert.equal(await w.locator('a[href="/projects/e2e-project/wiki/Macros"]', { hasText: 'link to this page' }).count(), 1);
assert.equal(await w.locator('a[href="http://www.twitter.com/redmine"]').count(), 1);
assert.equal(await w.locator('.wiki_extensions_lastupdated_at').count(), 1);
assert.equal(await w.locator('.wiki_extensions_lastupdated_by a.user').count(), 1);
assert.equal(await w.locator('a.wiki_extensions_fn').count(), 2, 'two footnote marks');
assert.equal(await w.locator('.wiki_extensions_fnlist li').count(), 2, 'footnote list added at the end');
assert.equal(await w.locator('#boxed.wikiext-e2e-box').count(), 1, 'div_start_tag with id and class');
assert.equal(await w.locator('ol.wikiext-popularity li').count() >= 1, true, 'popularity lists the counted page');
assert.equal(await w.locator('.wiki_extensions_recent a').count() >= 5, true, 'recent lists pages');
assert.equal(await w.locator('.wikiext-page-break').count(), 1);
assert.equal(await w.locator('iframe[src="http://127.0.0.1:3000/robots.txt"][width="300"]').count(), 1);
assert.equal(await w.locator('video[width="160"][height="90"][controls]').count(), 1);
assert.equal(await w.getByText('New page', { exact: true }).count(), 1, 'new_page link');
await t.shot('all-macros', 'Every display macro rendered as manager: new marks, project/wiki/twitter links, last update, footnotes with list, styled div, count, popularity, recent, page break, iframe, video, new page form', {});

// {{new_page}}: the link opens a title field, Create goes to the new page
await w.getByText('New page', { exact: true }).click();
const title = t.page.locator('input[id^="new_page_title_"]');
await title.waitFor({ state: 'visible' });
await t.page.waitForTimeout(800); // jQuery UI 'blind' animation
await title.fill('Made by new_page');
await t.shot('new-page-form', 'new_page: the link opened the title field');
await t.page.getByText('Create', { exact: true }).click();
await t.page.waitForURL(/\/wiki\/Made(%20|_)by(%20|_)new_page/);
await t.settle();
assert.equal(await t.page.locator('#content_text').count(), 1, 'edit form of the new page');
await t.shot('new-page-created', 'new_page: Create led to the edit form of the page "Made by new page"');
t.check('new_page');

await t.login('reporter');
await t.go(`${P}/Macros`, { allow: { requests: ['/missing.mp4'] } }); // the video URL is a placeholder
assert.equal(await t.page.locator('.wiki_extensions_fnlist li').count(), 2);
assert.equal(await t.page.getByText('New page', { exact: true }).count(), 0, 'no new_page link without edit permission');
await t.shot('reporter', 'The same page as reporter (no plugin permissions): display macros render; new_page shows nothing without the wiki edit permission');

await t.anonymous();
await t.go(`${P}/Macros`, { allow: { requests: ['/missing.mp4'] } }); // the video URL is a placeholder
await t.shot('anonymous', 'Anonymous on the public project sees the macros as well');

// failure paths
await t.login('manager');
await t.go(`${P}/Errors`);
const errors = await t.page.locator('.wiki.wiki-page').innerText();
assert.match(errors, /Error executing the iframe macro/);
assert.match(errors, /Error executing the new macro/);
assert.match(errors, /vote without a key: \[(\{\{vote\}\})?\]/);
assert.match(errors, /taggedpages without tags: \[(\{\{taggedpages\}\})?\]/);
await t.shot('errors', 'Invalid arguments: iframe without URL and new with a bad date show a macro error, vote and taggedpages without arguments render nothing (Redmine then shows the macro text); HTTP 200, no 500');

await t.done();
