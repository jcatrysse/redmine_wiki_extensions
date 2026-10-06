// Header, Footer and StyleSheet wiki pages, and emoticons with CommonMark and
// with Textile (the Textile rule moved to Textile::Filter in Redmine 7).
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('layout');
const W = '/projects/e2e-project/wiki';
const smileys = ['smile', 'sad', 'tongue', 'biggrin', 'wink', 'check', 'x_mark', 'warning'];

async function emoticonsLoaded() {
  const imgs = t.page.locator('.wiki.wiki-page img[src^="/wiki_extentions/emoticon/"]');
  const srcs = await imgs.evaluateAll(list => list.map(i => [i.getAttribute('src'), i.complete && i.naturalWidth > 0]));
  assert.deepEqual(srcs.map(s => s[0]), smileys.map(n => `/wiki_extentions/emoticon/${n}.png`));
  assert.ok(srcs.every(s => s[1]), 'every emoticon image loaded');
}

await t.login('manager');
await t.go(`${W}/Emoticons`);
const text = await t.page.locator('.wiki.wiki-page').innerText();
assert.match(text, /^Project header from the Header page/, 'Header page included first');
assert.match(text, /Project footer from the Footer page$/, 'Footer page included last');
await emoticonsLoaded();
const h1 = await t.page.locator('div.wiki-page h1').first().evaluate(e => getComputedStyle(e).color);
assert.equal(h1, 'rgb(200, 0, 0)', 'the StyleSheet wiki page is applied');
await t.shot('commonmark', 'CommonMark: the eight emoticons are images (all loaded from /wiki_extentions/emoticon/*.png), Header and Footer pages are included, the StyleSheet page colours the title red');

// the StyleSheet route itself
let r = await t.page.request.get(`${t.BASE}/projects/e2e-project/wiki_extensions/stylesheet.css`);
assert.equal(r.status(), 200);
assert.match(r.headers()['content-type'], /text\/css/);
assert.match(await r.text(), /rgb\(200, 0, 0\)/);
await t.go(`${W}/Header`);
assert.doesNotMatch(await t.page.locator('.wiki.wiki-page').innerText(), /Project footer/, 'the Header page does not include the footer');
await t.shot('header-page', 'The Header page itself is shown without header or footer around it');

// the private project's StyleSheet stays private
await t.login('outsider');
await t.go('/projects/e2e-private/wiki_extensions/stylesheet.css', { status: 403 });
await t.shot('outsider-stylesheet', 'outsider: the StyleSheet of the private project is refused (403); anonymous gets 403 too');
await t.anonymous();
await t.go('/projects/e2e-private/wiki_extensions/stylesheet.css', { status: 403 });
r = await t.page.request.get(`${t.BASE}/wiki_extentions/emoticon/smile.png`);
assert.equal(r.status(), 200);
assert.equal(r.headers()['content-type'], 'image/png');
r = await t.page.request.get(`${t.BASE}/wiki_extentions/emoticon/nothing.png`);
assert.equal(r.status(), 404);

// Textile: switch the text formatting as admin (sudo mode), look, switch back
await t.login('admin');
async function textFormatting(value) {
  await t.go('/settings?tab=general');
  await t.page.locator('#settings_text_formatting').selectOption(value);
  await t.page.locator('#tab-content-general input[type=submit]').click();
  await t.page.waitForLoadState('load');
  await t.sudo();
  await t.go('/settings?tab=general');
  assert.equal(await t.page.locator('#settings_text_formatting').inputValue(), value);
}
await textFormatting('textile');
try {
  await t.go(`${W}/Emoticons`);
  await emoticonsLoaded();
  const tx = await t.page.locator('.wiki.wiki-page').innerText();
  assert.match(tx, /^Project header from the Header page/);
  assert.match(tx, /Project footer from the Footer page$/);
  // the wrapper's id is removed by the formatter's sanitizer, with Textile as with CommonMark
  assert.equal(await t.page.locator('#wiki_extentions_header').count(), 0);
  await t.shot('textile', 'Textile: the same emoticons are images, Header/Footer included (the header wrapper loses its id here too, so #wiki_extentions_header rules never match)');
} finally {
  await textFormatting('common_mark');
}

await t.done();
