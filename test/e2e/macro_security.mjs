// Macros must not reveal the private project to a reader who cannot see it,
// and must not turn their arguments into markup.
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('macro_security');
const dialogs = [];

// manager is a member of e2e-private: the macros may show it
await t.login('manager');
t.page.on('dialog', d => { dialogs.push(d.message()); d.dismiss(); });
await t.go('/projects/e2e-project/wiki/Leaks');
let w = t.page.locator('.wiki.wiki-page');
assert.equal(await w.locator('a[href="/projects/e2e-private"]', { hasText: 'E2E private' }).count(), 1);
assert.equal(await w.locator('a[href="/projects/e2e-private/wiki/Secret"]').count() >= 1, true);
assert.equal(await w.locator('.wiki_extensions_lastupdated_at').count(), 1);
await t.shot('member', 'manager (member of e2e-private): project, wiki, lastupdated_at and taggedpages(secret-tag, project=all) show the private project and its Secret page');

// reporter is not: nothing of e2e-private may appear
for (const user of ['reporter', 'anonymous']) {
  if (user === 'anonymous') await t.anonymous(); else await t.login(user);
  await t.go('/projects/e2e-project/wiki/Leaks');
  w = t.page.locator('.wiki.wiki-page');
  const html = await w.innerHTML();
  // a macro that renders nothing is shown as its own source text, which the
  // page author wrote; what must not appear is what only the private project knows
  assert.equal(await w.locator('a[href^="/projects/e2e-private"]').count(), 0, `${user}: no link into e2e-private`);
  assert.ok(!html.includes('E2E private'), `${user}: no private project name`);
  assert.equal(await w.locator('ul.wikiext-taggedpages li').count(), 0, `${user}: no private page listed`);
  assert.equal(await w.locator('.wiki_extensions_lastupdated_at').count(), 0);
  await t.shot(`${user}-no-leak`, `${user}: the macros render nothing (Redmine shows their source text): no link into e2e-private, not its name "E2E private", no Secret page in taggedpages, no update time (all were shown before)`);
}

// markup in macro arguments
await t.login('reporter');
t.page.on('dialog', d => { dialogs.push(d.message()); d.dismiss(); });
await t.go('/projects/e2e-project/wiki/Unsafe', { allow: { requests: ['/x'] } });
await t.page.waitForTimeout(1000);
w = t.page.locator('.wiki.wiki-page');
assert.equal(await w.locator('img[onerror]').count(), 0);
assert.equal(await w.locator('iframe[onload]').count(), 0);
assert.match(await w.innerText(), /X<img src=x onerror=alert\('fn'\)>\*1/);
assert.deepEqual(dialogs, [], 'no script ran');
await t.shot('unsafe-escaped', "Footnote word <img src=x onerror=alert('fn')> and iframe width 100\" onload=\"alert('iframe') are shown as text / dropped: no image, no onload, no dialog");

await t.done();
