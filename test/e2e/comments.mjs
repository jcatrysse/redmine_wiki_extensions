// {{comment_form}} and {{comments}}: add, reply, edit, delete, the mail to
// watchers, the activity entry, and every refusal (permission absent, other
// author, other project, private project, empty comment).
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('comments');
const PAGE = '/projects/e2e-project/wiki/Comments';
const stamp = Date.now().toString(36);
const tree = () => t.page.locator('ul.IsRoot');
// the displayed text of a comment (its hidden edit field holds the same text)
const shown = txt => t.page.locator('div[id^="wikiextensions_comment_text_"]', { hasText: txt });

async function csrf() {
  return t.page.locator('meta[name="csrf-token"]').getAttribute('content');
}
async function post(path, form) {
  return t.page.request.post(t.BASE + path, { form: { authenticity_token: await csrf(), ...form }, maxRedirects: 0 });
}
async function pageId(project, title) {
  const r = await t.page.request.get(`${t.BASE}/projects/${project}/wiki/${title}.json`, { headers: { 'X-Redmine-API-Key': '' } });
  return r.ok() ? (await r.json()).wiki_page?.id : null;
}

// --- manager: every permission
await t.login('manager');
await t.go(PAGE);
assert.equal(await shown('First comment, by the manager.').count(), 1);
assert.equal(await shown('A reply by the admin.').count(), 1);
await t.page.getByRole('link', { name: 'Add a comment' }).first().click();
const area = t.page.locator('textarea[id^="add_comment_area_"]');
await area.waitFor({ state: 'visible' });
// work item 4: the wiki toolbar is drawn above the comment field
assert.ok(await t.page.locator('div[id^="add_comment_form_div"] .jstElements').count() >= 1, 'toolbar drawn');
await area.fill(`Manager comment ${stamp} with *emphasis*`);
await t.shot('form-with-toolbar', 'The comment form opened from {{comment_form}} with the wiki toolbar (it was missing on CommonMark: "jsToolBar is not defined")');
t.check('open form');
await t.page.locator('div[id^="add_comment_form_div"] input[type=submit]').click();
await t.page.waitForLoadState('load');
assert.equal(await shown(`Manager comment ${stamp} with`).count(), 1);
assert.equal(await tree().locator('em', { hasText: 'emphasis' }).count() >= 1, true, 'comment text is formatted');
await t.shot('added', 'The new comment is listed, its text formatted');
t.check('add');

// reply to the first comment
const first = t.page.locator('li.list_item', { has: shown('First comment, by the manager.') }).first();
await first.locator('> div.contextual a.icon-comment').click();
const reply = first.locator('textarea[id^="wiki_extensions_comment_reply_area_"]').first();
await reply.waitFor({ state: 'visible' });
await reply.fill(`Reply ${stamp}`);
await first.locator('input[type=submit][value="Reply"]').first().click();
await t.page.waitForLoadState('load');
const firstAgain = t.page.locator('li.list_item', { has: shown('First comment, by the manager.') }).first();
assert.equal(await firstAgain.locator('ul.list div[id^="wikiextensions_comment_text_"]', { hasText: `Reply ${stamp}` }).count(), 1, 'reply nested under the first comment');
await t.shot('replied', 'The reply is nested under the comment it answers');
t.check('reply');

// edit the manager's own comment
const mine = () => t.page.locator('li.list_item', { has: shown(`Manager comment ${stamp} with`) }).last();
await mine().locator('> div.contextual a.icon-edit.wiki_font_size').click();
const edit = mine().locator('textarea[id^="wiki_extensions_comment_edit_area_"]');
await edit.waitFor({ state: 'visible' });
await edit.fill(`Manager comment ${stamp} edited`);
await mine().locator('input[type=submit][value="Apply"]').click();
await t.page.waitForLoadState('load');
assert.equal(await shown(`Manager comment ${stamp} edited`).count(), 1);
await t.shot('edited', 'The edited comment shows the new text');
t.check('edit');

// delete: a DELETE request behind a confirmation
const del = t.page.locator('li.list_item', { has: shown(`Manager comment ${stamp} edited`) }).last()
  .locator('> div.contextual a.icon-del');
assert.equal(await del.getAttribute('data-method'), 'delete');
assert.equal(await del.getAttribute('data-confirm'), 'Are you sure?');
let confirmText = '';
t.page.once('dialog', d => { confirmText = d.message(); d.accept(); });
await del.click();
await t.page.waitForLoadState('load');
await t.settle();
assert.equal(confirmText, 'Are you sure?');
assert.equal(await shown(`Manager comment ${stamp} edited`).count(), 0);
await t.shot('deleted', 'After confirming "Are you sure?" the comment is gone');
t.check('delete');

// a GET to destroy_comment no longer deletes anything (CSRF through an image)
await t.go('/projects/e2e-project/wiki_extensions/destroy_comment?comment_id=1', { status: 404 });
await t.shot('delete-by-get-refused', 'GET /wiki_extensions/destroy_comment is not routed any more: 404, nothing deleted');

// empty comment
await t.go(PAGE);
await t.page.getByRole('link', { name: 'Add a comment' }).first().click();
await t.page.locator('div[id^="add_comment_form_div"] input[type=submit]').click();
await t.page.waitForLoadState('load');
assert.match(await t.page.locator('#flash_error').innerText(), /Comment cannot be blank/);
await t.shot('empty-refused', 'An empty comment is refused with "Comment cannot be blank" (before: silently dropped, watchers still mailed)');
t.check('empty');

// activity
await t.go('/projects/e2e-project/activity?show_wiki_comment=1');
assert.ok(await t.page.locator('#activity dt', { hasText: 'Wiki comment: Comments' }).count() >= 1);
await t.shot('activity', 'Project activity lists the wiki comments (provider scope now a proc: no deprecation)');

// --- admin comments: the manager watches the page and gets a mail
await t.login('admin');
const since = Date.now() - 1000;
await t.go(PAGE);
await t.page.getByRole('link', { name: 'Add a comment' }).first().click();
await t.page.locator('textarea[id^="add_comment_area_"]').fill(`Admin comment ${stamp}`);
await t.page.locator('div[id^="add_comment_form_div"] input[type=submit]').click();
await t.page.waitForLoadState('load');
await t.page.waitForTimeout(1500);
const mails = t.mails(since).filter(m => m.body.includes(`Admin comment ${stamp}`));
assert.ok(mails.some(m => /manager@example\.net/.test(m.to + m.body)), `mail to the watching manager (got ${mails.map(m => m.to)})`);
assert.ok(mails.every(m => /commented/.test(m.body)));
await t.shot('admin-commented', `Admin's comment is listed; ${mails.length} notification mail(s) written for it, one to the watching manager`);

// --- commenter: may comment, may not touch other authors' comments or other projects
await t.login('commenter');
await t.go(PAGE);
const adminComment = t.page.locator('li.list_item', { has: shown(`Admin comment ${stamp}`) }).last();
assert.equal(await adminComment.locator('> div.contextual a.icon-comment').count(), 1);
// Edit and Delete only where the server allows them: own comments (or admin)
assert.equal(await adminComment.locator('> div.contextual a.icon-edit').count(), 0, 'no Edit on the admin comment');
assert.equal(await adminComment.locator('> div.contextual a.icon-del').count(), 0, 'no Delete on the admin comment');
await t.shot('commenter', 'commenter (comment permissions only): can add and reply; no Edit or Delete on other people\'s comments (they used to be shown and then refused with 403)');
const commentId = (await adminComment.getAttribute('id')).replace('wikiextensions_comment_li_', '');
let r = await post('/projects/e2e-project/wiki_extensions/update_comment', { comment_id: commentId, comment: 'hijacked' });
assert.equal(r.status(), 403, 'editing the admin comment is refused');
r = await t.page.request.delete(`${t.BASE}/projects/e2e-project/wiki_extensions/destroy_comment?comment_id=${commentId}`,
  { headers: { 'X-CSRF-Token': await csrf() }, maxRedirects: 0 });
assert.equal(r.status(), 403, 'deleting the admin comment is refused');
// e2e-private: commenter is no member; its Secret page id comes from the admin seed
const secretId = Number(process.env.RMP_SECRET_PAGE_ID || 0) || null;
await t.login('admin');
const sid = await (async () => {
  await t.go('/projects/e2e-private/wiki/Secret');
  const r2 = await t.page.request.get(`${t.BASE}/projects/e2e-private/wiki/Secret.json`);
  return (await r2.json()).wiki_page.id;
})().catch(() => secretId);
await t.login('commenter');
await t.go(PAGE);
r = await post('/projects/e2e-project/wiki_extensions/add_comment', { wiki_page_id: String(sid), comment: 'into a private project' });
assert.equal(r.status(), 404, `commenting on e2e-private's page through e2e-project is refused (page ${sid})`);
await t.go(PAGE);
await t.shot('commenter-refusals', `Requests as commenter: edit and delete of the admin's comment 403, add_comment on e2e-private page ${sid} through e2e-project 404; the page shows no trace of it`);
assert.equal(await t.page.getByText('into a private project').count(), 0);

// --- reporter: no plugin permissions
await t.login('reporter');
await t.go(PAGE);
assert.equal(await t.page.getByRole('link', { name: 'Add a comment' }).count(), 0, 'no comment form');
assert.equal(await shown('First comment, by the manager.').count(), 1, 'comments are visible (public permission)');
assert.equal(await tree().locator('a', { hasText: 'Reply' }).count(), 0);
assert.equal(await tree().locator('a.icon-del').count(), 0);
await t.shot('reporter', 'reporter: reads the comments, gets no form and no reply, edit or delete links');
r = await post('/projects/e2e-project/wiki_extensions/add_comment', { wiki_page_id: '1', comment: 'not allowed' });
assert.equal(r.status(), 403, 'add_comment refused for reporter');

// --- outsider: the private project stays invisible
await t.login('outsider');
await t.go('/projects/e2e-private/wiki/Secret', { status: 403 });
await t.shot('outsider-private', 'outsider: the private project wiki is refused (403)');
await t.go(PAGE);
r = await post('/projects/e2e-private/wiki_extensions/add_comment', { wiki_page_id: String(sid), comment: 'outsider' });
assert.equal(r.status(), 403, 'add_comment in e2e-private refused for outsider');

await t.done();
