// {{vote}} and {{show_vote}}: a click counts once per session, through a POST
// (the explicit vote route accepts POST only; the macro used to send GET -> 404).
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('vote');
const PAGE = '/projects/e2e-project/wiki/Vote';
const count = async () => Number((await t.page.locator('span.wikiext-show-vote').innerText()).trim());
const inline = async () => Number((await t.page.locator('span.wikiext-vote span[id^="wikiext-vote-"]').innerText()).trim());

async function voteOnce(user) {
  await t.go(PAGE);
  const before = await count();
  const posted = t.page.waitForResponse(r => r.url().includes('/wiki_extensions/vote'));
  await t.page.locator('span.wikiext-vote a', { hasText: 'I like it' }).click();
  const r = await posted;
  assert.equal(r.request().method(), 'POST', 'the vote is posted');
  assert.equal(r.status(), 200, `vote answered ${r.status()}`);
  await t.page.waitForTimeout(300);
  assert.equal(await inline(), before + 1, `${user}: the inline count went up`);
  t.check(`vote ${user}`);
  return before;
}

await t.login('manager');
const before = await voteOnce('manager');
await t.shot('voted', `manager clicked "I like it": POST /wiki_extensions/vote answered 200, the count went from ${before} to ${before + 1}`);
// a second click in the same session does not count again
const posted = t.page.waitForResponse(r => r.url().includes('/wiki_extensions/vote'));
await t.page.locator('span.wikiext-vote a', { hasText: 'I like it' }).click();
await posted;
await t.page.waitForTimeout(300);
assert.equal(await inline(), before + 1, 'second click in the same session counted once');
await t.go(PAGE);
assert.equal(await count(), before + 1, '{{show_vote}} shows the stored count');
await t.shot('voted-once', 'After a second click and a reload {{show_vote}} still shows one more vote: one vote per session');

// reporter: wiki_extensions_vote is a public permission
await t.login('reporter');
await voteOnce('reporter');
await t.shot('reporter-voted', 'reporter (no plugin permissions) can vote: the permission is public');

// a GET to the vote URL is not routed (it was the cause of the 404)
await t.go('/projects/e2e-project/wiki_extensions/vote?target_class_name=WikiContent&target_id=1&key=like', { status: 404 });
await t.shot('vote-get-404', 'GET /wiki_extensions/vote is not routed: 404 (what every vote click got before the fix)');

// outsider: voting in the private project is refused
await t.login('outsider');
await t.go(PAGE);
const token = await t.page.locator('meta[name="csrf-token"]').getAttribute('content');
const r = await t.page.request.post(`${t.BASE}/projects/e2e-private/wiki_extensions/vote`,
  { form: { authenticity_token: token, target_class_name: 'WikiContent', target_id: '1', key: 'like' } });
assert.equal(r.status(), 403);
await t.shot('outsider', 'outsider: POST /projects/e2e-private/wiki_extensions/vote answered 403');

await t.done();
