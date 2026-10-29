// Footnotes of text without a wiki page (issue and new-page previews) belong
// to that render only: another user's next preview must not list them or
// continue their numbering.
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('footnotes');

async function previewIssue(text) {
  await t.go('/projects/e2e-project/issues/new');
  await t.page.fill('#issue_description', text);
  await t.page.locator('#issue_description').locator('xpath=ancestor::div[contains(@class,"jstEditor")]/preceding-sibling::div[contains(@class,"jstTabs")]//a[contains(@class,"tab-preview")]').click();
  const preview = t.page.locator('.wiki-preview').first();
  await preview.locator('a.wiki_extensions_fn').first().waitFor();
  return preview;
}

await t.login('manager');
let preview = await previewIssue('Manager draft{{fn(draft, manager private note)}}');
assert.equal(await preview.locator('a.wiki_extensions_fn').innerText(), '*1');
await t.shot('issue-preview-manager', 'manager previews a new issue with a footnote and no fnlist: the footnote is marked *1');

await t.login('reporter');
preview = await previewIssue('Reporter text{{fn(mine, reporter note)}}\n\n{{fnlist}}');
const text = await preview.innerText();
assert.doesNotMatch(text, /manager private note/, 'the manager\'s footnote does not reach the reporter');
assert.equal(await preview.locator('a.wiki_extensions_fn').innerText(), '*1', 'numbering starts at 1');
assert.equal(await preview.locator('.wiki_extensions_fnlist li').count(), 1, 'only the reporter\'s footnote is listed');
await t.shot('issue-preview-reporter', 'reporter previews right after: only "mine: reporter note", numbered *1, nothing of the manager\'s preview');

await t.login('manager');
await t.go('/projects/e2e-project/wiki/Footnote_preview');
await t.page.fill('#content_text', 'Redmine{{fn(Redmine, a project management web application)}} and Rails{{fn(Rails, a web framework)}}\n\n{{fnlist}}');
await t.page.locator('a.tab-preview').first().click();
preview = t.page.locator('.wiki-preview').first();
await preview.locator('.wiki_extensions_fnlist').waitFor();
assert.deepEqual(await preview.locator('a.wiki_extensions_fn').allInnerTexts(), ['*1', '*2']);
assert.equal(await preview.locator('.wiki_extensions_fnlist li').count(), 2);
await t.shot('wiki-new-page-preview', 'Preview of a new wiki page: footnotes *1 and *2 and their list, as before');

await t.done();
