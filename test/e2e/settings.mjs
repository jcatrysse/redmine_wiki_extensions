// Settings: the project tab (tag dropdown options, up to five project menu
// tabs), the plugin-wide dropdown options, and the module switch.
import { e2e } from '../../.codex/e2e/lib.mjs';
import assert from 'node:assert/strict';

const t = await e2e('settings');
const SETTINGS = '/projects/e2e-project/settings/wiki_extensions';
const dropdown = () => t.page.locator('select[name="extension[tags][0]"] option').allInnerTexts();

async function projectSettings({ options = '', tab = null }) {
  await t.go(SETTINGS);
  await t.page.locator('#setting_tag_dropdown_options').fill(options);
  const box = t.page.locator('#menus_0_enabled');
  if (tab) {
    if (!(await box.isChecked())) await box.check();
    await t.page.locator('#menus_0_title').fill(tab.title);
    await t.page.locator('#menus_0_page_name').fill(tab.page);
  } else if (await box.isChecked()) {
    await box.uncheck();
  }
  await t.page.locator('#wiki_extensions_settings input[type=submit]').click();
  await t.page.waitForLoadState('load');
  assert.match(await t.page.locator('#flash_notice').innerText(), /Successful update/);
}

await t.login('manager');
await t.go(SETTINGS);
assert.equal(await t.page.locator('#tab-wiki_extensions').count(), 1);
const labels = await t.page.locator('#wiki_extensions_settings .wiki-menu-entry > b').allInnerTexts();
assert.deepEqual(labels, ['Tab#1', 'Tab#2', 'Tab#3', 'Tab#4', 'Tab#5'], 'exactly the five tabs');
await projectSettings({ options: 'doc-a\ndoc-b', tab: { title: 'Handbook', page: 'Tag_index' } });
assert.equal(await t.page.locator('#setting_tag_dropdown_options').inputValue(), 'doc-a\ndoc-b');
await t.shot('project-tab-saved', 'manager saved the project tab: dropdown options doc-a/doc-b and menu tab #1 "Handbook" -> page Tag_index ("Successful update."); exactly Tab#1 to Tab#5 (a stray Tab#0 showed up before)');

// the menu tab
const menuTab = t.page.locator('#main-menu a.wiki-extensions1');
assert.equal(await menuTab.innerText(), 'Handbook');
await menuTab.click();
await t.page.waitForLoadState('load');
assert.match(t.page.url(), /\/projects\/e2e-project\/wiki\/Tag_index$/);
await t.settle();
await t.shot('menu-tab', 'The project menu shows "Handbook"; clicking it went through forward_wiki_page to the Tag_index page', {});
t.check('menu tab');

// a tab that is not configured, or not 1 to 5, is not found (and no row is created)
await t.go('/projects/e2e-project/wiki_extensions/forward_wiki_page?menu_id=2', { status: 404 });
await t.go('/projects/e2e-project/wiki_extensions/forward_wiki_page', { status: 404 });
await t.go(SETTINGS);
assert.equal(await t.page.locator('#wiki_extensions_settings .wiki-menu-entry').count(), 5);

// the project's dropdown options replace the defaults on the edit form
await t.go('/projects/e2e-project/wiki/Tagged_two/edit');
assert.deepEqual(await dropdown(), ['', 'doc-a', 'doc-b', 'approved'], 'project options (plus the current first tag, kept)');
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded();
await t.page.locator('select[name="extension[tags][0]"]').click();
await t.shot('project-dropdown', 'The first tag field offers the project options doc-a and doc-b, plus "approved" because the page carries it');
await t.page.keyboard.press('Escape');

// reporter: sees and follows the tab, may not open the settings
await t.login('reporter');
await t.go('/projects/e2e-project');
await t.page.locator('#main-menu a.wiki-extensions1').click();
await t.page.waitForLoadState('load');
assert.match(t.page.url(), /\/wiki\/Tag_index$/);
await t.go(SETTINGS, { status: 403 });
await t.shot('reporter-settings-403', 'reporter: follows the "Handbook" tab, but the project settings are refused (403)');
let token = await t.page.locator('meta[name="csrf-token"]').getAttribute('content');
await t.go('/projects/e2e-project/wiki/Tag_index');
token = await t.page.locator('meta[name="csrf-token"]').getAttribute('content');
let r = await t.page.request.post(`${t.BASE}/projects/e2e-project/wiki_extensions_settings`,
  { form: { authenticity_token: token, 'setting[tag_dropdown_options]': 'hacked' } });
assert.equal(r.status(), 403, 'posting the settings is refused');

// outsider
await t.login('outsider');
await t.go('/projects/e2e-private/settings/wiki_extensions', { status: 403 });
await t.go('/projects/e2e-private/wiki_extensions/forward_wiki_page?menu_id=1', { status: 403 });
await t.shot('outsider', 'outsider: settings and menu tabs of the private project are refused (403)');

// admin: plugin-wide options apply when the project has none
await t.login('admin');
await t.go('/settings/plugin/redmine_wiki_extensions');
await t.sudo();
const global = t.page.locator('textarea[name="settings[tag_dropdown_options]"]');
const before = await global.inputValue();
await global.fill('global-x\nglobal-y');
await t.page.locator('#settings input[type=submit], form input[type=submit][name=commit]').first().click();
await t.page.waitForLoadState('load');
await t.sudo();
await t.shot('plugin-settings', 'Administration > Plugins > Wiki Extensions: plugin-wide dropdown options set to global-x/global-y');
await t.login('manager');
await projectSettings({ options: '', tab: null });
await t.go('/projects/e2e-project/wiki/Tagged_two/edit');
assert.deepEqual(await dropdown(), ['', 'global-x', 'global-y', 'approved'], 'plugin-wide options when the project has none');
await t.page.locator('#wiki_extensions_tag_form').scrollIntoViewIfNeeded();
await t.shot('global-dropdown', 'With the project options emptied, the first tag field offers the plugin-wide options; the menu tab is gone again');
assert.equal(await t.page.locator('#main-menu a.wiki-extensions1').count(), 0);
await t.login('admin');
await t.go('/settings/plugin/redmine_wiki_extensions');
await t.sudo();
await t.page.locator('textarea[name="settings[tag_dropdown_options]"]').fill(before);
await t.page.locator('#settings input[type=submit], form input[type=submit][name=commit]').first().click();
await t.page.waitForLoadState('load');
await t.sudo();

// module off: no tag form, no settings tab, no macros
await t.login('manager');
async function moduleEnabled(on) {
  // Redmine 7 lists the modules on the project's information form
  await t.go('/projects/e2e-private/settings/info');
  const box = t.page.locator('input[name="project[enabled_module_names][]"][value="wiki_extensions"]');
  if ((await box.isChecked()) !== on) await box.setChecked(on);
  await t.page.locator('form', { has: box }).locator('input[type=submit]').first().click();
  await t.page.waitForLoadState('load');
  assert.match(await t.page.locator('#flash_notice').innerText(), /Successful update/);
}
await moduleEnabled(false);
try {
  await t.go('/projects/e2e-private/wiki/Secret/edit');
  assert.equal(await t.page.locator('#wiki_extensions_tag_form').count(), 0, 'no tag fields');
  await t.go('/projects/e2e-private/settings');
  assert.equal(await t.page.locator('#tab-wiki_extensions').count(), 0, 'no settings tab');
  await t.shot('module-off', 'Module "Wiki extensions" disabled in e2e-private: no Wiki Extensions settings tab (and no tag fields on the edit form)');
  await t.go('/projects/e2e-private/wiki_extensions/tag?tag_id=1', { status: 403 });
} finally {
  await moduleEnabled(true);
}

await t.done();
