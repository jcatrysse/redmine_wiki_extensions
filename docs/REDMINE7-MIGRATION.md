# Redmine 7 migration: redmine_wiki_extensions

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL and MariaDB, every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_wiki_extensions` |
| GEOxyz runs today | `Redmine-5.1` |
| Upstream | haru/redmine_wiki_extensions main @ 9505dfec11b9beed953c2767302f7c93be96dfc2 (v1.3.0, 2026-07-23) |
| Runs on Redmine 7 as is | NEE |
| Upstream sync | SYNC AANBEVOLEN: Base = Redmine-5.1 + merge of upstream main 1.3.0 (9505dfe); 28 conflict hunks resolved keeping GEOxyz explicit routes, tag_dropdown_options setting/migration 0015, tag macros, CommonMark emoticons; brings R7 Textile Filter::RULES fix and footnote XSS fix. Not fork main (1.1.0, no R7 fix) and not the claude guard branch (drops Textile emoticons silently). Note: Redmine-5.1 is 11 ahead / 39 behind fork main, not the reverse. |
| After sync | JA |
| After this session (2026-10-06) | JA: tests green on PostgreSQL and MariaDB, every function e2e on both, OpenAI review resolved. Not mergeable on Redmine 5.1 (`requires_redmine 6.0.0` since the upstream merge). |
| Complexity (1 trivial .. 5 rewrite) | 3 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `d86422f` (updated at the end of the migration session, see "Session result") |

## Already on this branch

- `2e5cfcd` Merge upstream haru/redmine_wiki_extensions main (9505dfe) for Redmine 7
- `deb638a` Restore the wiki_extensions_stylesheet route name
- `480e588` Load the tag form's add icon through the asset pipeline
- Migration session (2026-10-06), in order: `85bd75b` test gems, `1fba7e5` broken GEOxyz tests,
  `2a3243c` vote POST, `8bd2ae5` settings tab test, `f1ec112` first tag kept, `76f949d` tag form XSS,
  `469ff2f` + `451419a` timestamped tag migration, `9a6ae0c` YARD, `efaad26` settings without menus,
  `794c15a` emoticon tests, `4ebf95f` activity scope proc, `6870793` comment toolbar, `4a5d9cf`
  comments scoped to the project, `a52abd9` no mail for unsaved comments, `1668c16` tag page scoped,
  `e541bb5` delete via DELETE, `3c2794d` macros hide invisible projects, `839673a` footnote/iframe
  escaping, `4e5ccf7` author name escaping, `3c42457` no eval, `35157cd` string session keys,
  `f25bac7` menu tabs 1-5 only, `4088a4c` vote without key; e2e scenarios, screenshots and reviews.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. Note: migration 0015 (tag_dropdown_options) is GEOxyz-only; a future upstream 0015 will collide. Rename it to a timestamped migration before upstream reaches 0015.
   **DONE** `469ff2f`, `451419a`: now `20251130120000_add_tag_dropdown_options.rb`; adds the column only when missing and deletes the legacy `15-redmine_wiki_extensions` row (only while the plugin has no migration 15 of its own). Upgrade from legacy 15, rollback to 14 and to 0, and up again, run on PostgreSQL and MariaDB.

**Open items from the analysis** (Dutch; where they conflict with a decision or a priority item above, those win)

2. Declare test gems (shoulda, simplecov-lcov) in a plugin Gemfile test group; shoulda-context 2.0 crashes the Rails 8.1 test reporter on the first failure
   **DONE** `85bd75b`: `PluginGemfile` (Redmine loads `plugins/*/PluginGemfile`) evaluates the existing `Gemfile_for_test` unless the upstream tooling already copied it to the git-ignored `Gemfile`; reporter shim in `test/test_helper.rb`.
3. Fix two GEOxyz tests: wiki_extensions_setting_test.rb:52 (two fixture rows for project 1, non-deterministic find_by on PostgreSQL) and wiki_controller_test.rb:136 (expects 'MyString (2)', macro outputs 'MyString(N)')
   **DONE** `1fba7e5` (second fixture row on project 2; count derived; new exact test of taglist, taglist_commas, taglist_bullets).
4. CommonMark: {{comment_form}} uses render_to_string so jstoolbar is not loaded -> 'jsToolBar is not defined', no toolbar (saving comments works)
   **DONE** `6870793`: the macro calls `heads_for_wiki_formatter` in the page's view before `render_to_string` (kept, the PDF export needs it). The before-run shows the toolbar works on 5.1, so this was a Redmine 7 regression, not an old bug.
5. acts_as_activity_provider scope: select(...) must become a proc (deprecation, wiki_extensions_comment.rb:41)
   **DONE** `4ebf95f`, with a test that fails on the deprecation.
6. GEOxyz-only migration 0015 may collide with a future upstream 0015
   **DONE** with item 1.
7. Pre-existing XSS: tag names raw in value= attribute in _tags_form.html.erb
   **DONE** `76f949d` (also the autocomplete list now uses escape_javascript). Before-picture: the tag's onfocus fired on 5.1.

**Checks**

8. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
   **DONE**: 103 runs, 338 assertions, 0 failures, 0 errors on both (see "Session result"). Not run on 5.1: the branch declares `requires_redmine version_or_higher: '6.0.0'` (upstream 1.3.0), so it is not meant to stay 5.1-compatible; most fixes here would apply to 5.1 unchanged.
9. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
   **DONE, nothing needed**: the plugin neither hides, adds nor changes issue data (no issue patch, no issue hook, no `issues/show.api.rsb` override); its data is wiki-only (comments, tags, votes, counts). Webhook payloads are unaffected.
10. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).
   **DONE**: see "Inventory of functions" and `docs/e2e/`.

**Found and fixed during the session** (not in the analysis)

11. GEOxyz ff3dba7 made `vote` POST-only while the macro sent GET: every vote was a 404 (also in production 5.1). `2a3243c`.
12. Redmine 7 (GEOxyz) stores sessions as JSON: integer session keys come back as strings, so every vote click and every page view counted again. `35157cd`. Works on 5.1 (before-run).
13. GEOxyz 842d27f: a first tag that is not a dropdown option was silently deleted on save. `f1ec112`.
14. Security: comment actions accepted pages/comments of any project (`4a5d9cf`), the tag page listed tags of any project (`1668c16`), comment delete was a GET without confirmation (CSRF, `e541bb5`), `project`/`wiki`/`lastupdated_at`/`taggedpages` macros revealed private projects (`3c2794d`), stored XSS in `fn`/`fnlist`/`iframe` (`839673a`) and in the comment author name (`4e5ccf7`), `eval` of a request value in `WikiExtensionsVote#target` (`3c42457`).
16. Comment Edit/Delete links shown where the server refuses them (Jan's answer to open question 6). `f24ef06`.
15. Robustness: empty comment mailed watchers (`a52abd9`), settings POST without menus was a 500 (`efaad26`), vote without key a 500 (`4088a4c`), `forward_wiki_page` created a menu row for any `menu_id` and showed a stray "Tab#0" (`f25bac7`).

## Baseline (2026-10-06, before any change in this session, head `befa3b0`)

Redmine 7.0-stable-GEOxyz (7.0.1), Rails 8.1.3.1, Ruby 3.3.6. Test gems `shoulda` and
`simplecov-lcov` supplied through `RMP_TEST_GEMS` plus a temporary shim for the shoulda-context 2.0
reporter crash (without the shim the run aborts on the first failure with
`undefined local variable or method 'executable' for an instance of Rails::TestUnitReporter`).

| | PostgreSQL 16.15 | MariaDB 10.11.14 |
|---|---|---|
| minitest | 56 runs, 122 assertions, 2 failures, 0 errors | 56 runs, 122 assertions, 1 failure, 0 errors |
| failing | `wiki_extensions_setting_test.rb:52`, `wiki_controller_test.rb:136` | `wiki_controller_test.rb:136` |
| e2e smoke (`.codex/e2e/smoke.mjs`) | 8 plugin GET routes, 19 screenshots, 0 problems | |
| e2e core flows | 6 screenshots, 0 problems | |

Environment notes: `test_setup.sh` with `RMP_PROVISION_DB=1` fails when run as root (`$SUDO -u postgres`
with an empty `$SUDO`); worked around by creating the role by hand and `RMP_PROVISION_DB=0`. The
preinstalled Chromium is revision 1194, so Playwright 1.56.1 (not the latest) is used.

## Inventory of functions

Coverage list for the e2e set. Screenshots in `docs/e2e/` (PostgreSQL) and `docs/e2e/mariadb/` (same
names, MariaDB); every scenario also has a `<scenario>.md` with user, URL and caption per picture.
Users: admin, manager (every permission), commenter (plugin seed: comment permissions in e2e-project
only), reporter (no plugin permissions), outsider (no membership), anonymous.

| function | how a user reaches it | scenario | screenshots |
|---|---|---|---|
| `{{comment_form}}` with wiki toolbar | wiki page, "Add a comment" | comments.mjs | comments-form-with-toolbar, -added, -reporter (no form), -empty-refused |
| `{{comments}}` tree, reply, edit, delete | links next to each comment | comments.mjs | comments-replied, -edited, -deleted, -delete-by-get-refused, -commenter, -commenter-refusals |
| mail on new comment (notifiable `wiki_comment_added`) | admin comments, watcher gets a mail (`tmp/mails`) | comments.mjs | comments-admin-commented |
| activity provider "Wiki comments" | project activity | comments.mjs | comments-activity |
| private project refusals (comments) | outsider on e2e-private | comments.mjs | comments-outsider-private |
| tag fields on the wiki edit form (dropdown, free text, autocomplete, + icon) | edit any page | tags.mjs | tags-edit-first-tag-kept, -saved-tags-kept, -autocomplete, -saved-new-tags, -tag-name-escaped |
| `{{tags}}` and the tag page | tag link | tags.mjs | tags-tag-page, -reporter-tag-page, -reporter-tag-ids, -outsider-private-tag |
| `{{tagcloud}}`, `{{taglist}}`, `{{taglist_commas}}`, `{{taglist_bullets}}`, `{{taggedpages}}` (OR, AND) | Tag_index page | tags.mjs | tags-tag-index |
| `{{vote}}`, `{{show_vote}}` | Vote page | vote.mjs | vote-voted, -voted-once, -reporter-voted, -vote-get-404, -outsider |
| `{{new}}`, `{{project}}`, `{{wiki}}`, `{{twitter}}`, `{{lastupdated_at}}`, `{{lastupdated_by}}`, `{{fn}}`/`{{fnlist}}`, `{{div_start_tag}}`/`{{div_end_tag}}`, `{{count}}`/`{{show_count}}`, `{{popularity}}`, `{{recent}}`, `{{page_break}}`, `{{iframe}}`, `{{video_tag}}` | Macros page | macros.mjs | macros-all-macros, -reporter, -anonymous |
| `{{new_page}}` | "New page" link on the Macros page | macros.mjs | macros-new-page-form, -new-page-created |
| invalid macro arguments | Errors page | macros.mjs | macros-errors |
| macros and private projects, escaping of arguments | Leaks and Unsafe pages | macro_security.mjs | macro_security-member, -reporter-no-leak, -anonymous-no-leak, -unsafe-escaped |
| Header and Footer pages | any wiki page | layout.mjs | layout-commonmark, -header-page |
| StyleSheet page (`/projects/:id/wiki_extensions/stylesheet.css`) | head of every wiki page | layout.mjs | layout-commonmark, -outsider-stylesheet |
| emoticons, CommonMark and Textile (`/wiki_extentions/emoticon/*.png`) | Emoticons page; admin switches text formatting | layout.mjs | layout-commonmark, -textile |
| project settings tab: tag dropdown options, five menu tabs | Project settings > Wiki Extensions | settings.mjs | settings-project-tab-saved, -project-dropdown, -reporter-settings-403, -outsider |
| project menu tabs (`forward_wiki_page`) | "Handbook" tab in the project menu | settings.mjs | settings-menu-tab |
| plugin-wide dropdown options | Administration > Plugins > configure | settings.mjs | settings-plugin-settings, -global-dropdown |
| module switch | project settings, module "Wiki extensions" off | settings.mjs | settings-module-off |
| every plugin GET route, core issue flows | `.codex/e2e/smoke.mjs`, `core.mjs` | smoke, core | smoke-01..18, core-* |

No REST API, rake task, cron job or mail handler in this plugin. The comment mail is checked in
comments.mjs (file delivery). The PDF export of a page with `{{comment_form}}` is covered by a
functional test.

## GEOxyz changes to review or re-apply

These GEOxyz commits are on the branch GEOxyz runs today and therefore on this branch. Review each one against the code it now sits on (upstream merges and Redmine 7 core): drop it if upstream or core now does the same, rewrite it if it is not up to the quality rules below (tests, I18n, security, portability), keep it otherwise. Record the verdict per commit in this file.

| commit | date | subject | verdict |
|---|---|---|---|
| `e0b64b3` | 2026-05-31 | Add emoticon support for CommonMark formatter | KEEP. Still needed (upstream has Textile emoticons only). Tests added in `794c15a`. |
| `46ffc27` | 2026-05-31 | Fix emoticon route missing and url_helpers load-order issue | KEEP. Upstream now declares the same emoticon route; the render-time `url_helpers` call stays. Tested in `794c15a`. |
| `3a2caa6` | 2025-11-30 | Feature: configurable settings | KEEP, reworked: migration renamed to a timestamp (`469ff2f`), YARD docs (`9a6ae0c`), POST without menus no longer a 500 (`efaad26`), its broken test fixed (`1fba7e5`). Locales: all 15 carry its keys. |
| `842d27f` | 2025-11-30 | Feature: additional macro's | KEEP, fixed: a first tag that is not a dropdown option was silently deleted on save (`f1ec112`), comments translated to English, test fixed and tightened (`1fba7e5`). |
| `ff3dba7` | 2025-11-30 | Defect: dynamic :action segment in a route is deprecated | KEEP (explicit routes, no Rails 9 deprecation), fixed: it made `vote` POST-only while the macro sent GET, so every vote was a 404 (`2a3243c`); routing test added. |
| `5e60148` | 2025-11-30 | Defect: fix setting tab is not displayed (alias_method) | DROP: superseded by upstream's `ProjectsHelper.prepend` with the same permission check (from the merge). Tests prove the tab (`8bd2ae5`). |

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- Run `bundle exec rake redmine:plugins:migrate`: the renamed migration `20251130120000_add_tag_dropdown_options`
  finds the column present (from the old 0015), does not add it again and removes the old
  `15-redmine_wiki_extensions` row from `schema_migrations`. Run this branch's migrations before any later
  upstream sync that brings an upstream 0015.
- `PluginGemfile` adds the test group of `Gemfile_for_test` (shoulda, simplecov-lcov). They are not loaded in
  production; with `bundle config set without 'development test'` they are not even installed.
- Rows with `menu_no` outside 1 to 5 in `wiki_extensions_menus` (left by `forward_wiki_page` without
  `menu_id`) are now ignored; they can be deleted: `DELETE FROM wiki_extensions_menus WHERE menu_no NOT BETWEEN 1 AND 5`.
- Behaviour users will notice: votes work again (they were all 404); a view or a vote counts once per session
  again; deleting a comment now asks for confirmation; macros no longer show private projects to non-members;
  footnote words, iframe sizes and tag names containing markup are shown as text.
- On Redmine-5.1 today every wiki page of a project that has a `StyleSheet` wiki page answers 500 (fixed on
  this branch by deb638a); projects that avoided StyleSheet pages for that reason can use them again.

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow (tick
"e2e" for the browser run; screenshots come back as an artifact).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL and with MariaDB;
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
   - Run the whole e2e set once on MariaDB as well (`RMP_DB=mariadb`, then `start_server.sh --reset`).
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Session result (2026-10-06)

**Tests** (`./.codex/test_plugin.sh`, Redmine 7.0.1 7.0-stable-GEOxyz, Rails 8.1.3.1, Ruby 3.3.6):

| | PostgreSQL 16.15 | MariaDB 10.11.14 |
|---|---|---|
| baseline (before) | 56 runs, 122 assertions, 2 failures | 56 runs, 122 assertions, 1 failure |
| now | **105 runs, 350 assertions, 0 failures, 0 errors, 0 skips** | **105 runs, 350 assertions, 0 failures, 0 errors, 0 skips** |
| line coverage | 95.10% (989/1040) | 95.10% |

YARD: `100.00% documented` (51 methods). Boot and eager load: the production-mode server (eager loading)
started on both engines. Migrations down to 0 and up, and the upgrade from legacy 0015: OK on both.

**End to end** (`./.codex/e2e.sh`, production mode, fresh database each): 9 scripts (smoke, core, 7
plugin scenarios), 74 screenshots per engine (50 from the plugin scenarios), **0 problems on PostgreSQL
and 0 on MariaDB**. Every screenshot was opened during the session. Before-pictures (branch Redmine-5.1
on Redmine 5.1-stable, Ruby pin relaxed locally to 3.3 for this only): `docs/e2e/before/`, 8 pictures
plus `before-notes.txt` (vote GET 404, first tag blank, tag and macro script firing, stray Tab#0,
private project shown to a non-member, comment delete as plain GET link, StyleSheet page 500).

**Together with other GEOxyz plugins** (MariaDB, their `redmine70-migration` branches): redmineup_tags,
redmine_drawio, redmine_mermaid_macro, redmine_paste_as_wiki_tables, redmine_description_macros,
redmine_more_previews (the ones that also touch wiki formatting or tags). Migrations OK, plugin tests
103 runs 0 failures, full e2e set 0 problems. No failure appears only in combination. The coordinator's
harness with all GEOxyz plugins was not available in this session.

**Review**: own adversarial review of the whole diff found three more issues, fixed (`451419a`,
`4088a4c`, and the copyright line). OpenAI review (`gpt-5`, `docs/reviews/openai-2026-10-06-4088a4c.md`):
one finding, rejected with evidence (Redmine's own `assert_include` helper); nothing accepted, so no
second round was needed.

**Tooling notes** (not changed, `.codex` is shared): `test_setup.sh` with `RMP_PROVISION_DB=1` fails as
root (`$SUDO -u postgres` with empty `$SUDO`); `start_server.sh` writes `configuration.yml` under
`default:`, so the test environment also delivers mail to files (mail tests then see no deliveries); the
server database defaults to `redmine_e2e` even for another checkout (set `RMP_SERVER_DB_NAME`);
`redmine_clone.sh` with a second checkout inside the plugin copies the first checkout into it.

## Findings not fixed (pre-existing, upstream behaviour; written down, not changed)

- CommonMark and Textile both strip the `id` of the `<div id="wiki_extentions_header">` /
  `wiki_extentions_footer` wrappers (core sanitizers), so StyleSheet rules on those ids never match; the
  header and footer text is still included. Seen on Redmine 7; likely the same on 5.1.
- A page with an explicit `{{fnlist}}` shows the footnote list twice (the plugin always appends one).
- Headings that macros output (`{{tagcloud}}`'s "Tags", comment headers) get Redmine's "edit this section"
  pencil, pointing at the wrong section.
- Emoticons have no left boundary: `f(x) ` becomes the "x" icon (both formatters).
- `vote` accepts any `target_class_name`/`target_id`; it only counts, but the count of an object in another
  project can be read and raised. `show_vote` and `show_comments` are permission-only routes without an
  action (404).
- `wiki_extensions_settings_controller#update` ends with `throw e` (an UncaughtThrowError instead of the
  original error) when saving fails.
- `field_tag_disabled` is missing in 12 of 15 locales (upstream; the setting has no UI).
- The emoticon action builds a path from `params[:icon_name]`; not exploitable because Rails route
  segments cannot contain dots or slashes (verified on the running server: `..%2F` answers 404).

## Open questions for Jan

Answered by Jan on 2026-10-06; all six with the recommended option.

| # | question | answer |
|---|---|---|
| 1 | Test gems through `PluginGemfile` (`85bd75b`) | keep |
| 2 | Comment delete only by DELETE with confirmation (`e541bb5`) | keep, no GET |
| 3 | Macros hide private projects from non-members (`3c2794d`) | keep |
| 4 | Markup in footnote words and tag names shown as text (`839673a`, `76f949d`) | keep, always text |
| 5 | Disabled or unconfigured menu tab answers 404 (`f25bac7`) | keep 404 |
| 6 | Edit/Delete links on other people's comments | hide them unless author or admin: built in `f24ef06` (tests, e2e comments-commenter on both engines) |

No open questions remain.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why). Push after every
  commit, together with the updated status in this file: a cloud session can stop at a usage
  limit, and work that is not pushed is lost with its container.
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## Analysis report (2026-10-06, Dutch)

# redmine_wiki_extensions
- Gebruikte branch: Redmine-5.1 @ e0b64b3 (2026-05-31) - plugin id redmine_wiki_extensions, versie 0.9.6
- Upstream: haru/redmine_wiki_extensions - upstream HEAD main @ 9505dfe (2026-07-23, v1.3.0, "feature/redmine7"); develop zelfde datum
- Fork t.o.v. upstream: Redmine-5.1 heeft 11 commits die upstream niet heeft, waarvan 4 cherry-picks die upstream inhoudelijk al heeft. Echt eigen: 7 (FloWalchs video/div 9c4320c, 5e60148, ff3dba7, 842d27f, 3a2caa6, 46ffc27, e0b64b3). Er ontbreken 73 upstream-commits.
- Correctie op de gegeven feiten: Redmine-5.1 staat **11 vóór en 39 achter** fork-`main`, niet andersom (`git rev-list --left-right --count origin/main...origin/Redmine-5.1` = 39/11). Merge-base 68076b7 (2024-11-16). Fork-main (55ebb80, 1.1.0) is 34 commits achter upstream.
- Andere relevante branches: `claude/redmine7-rails8-compat` (690b696 op main, guard rond RULES). `fix/emoticon-commonmark-encoding` (e836b81 op 3a2caa6, alternatief voor 46ffc27 + e0b64b3: route, url_helpers, UTF-8-cast; 10 vóór / 39 achter main). Beide niet gewijzigd.

## 1. Werkt out of the box op Redmine 7?   NEE
- `FAIL boot`: `lib/wiki_extensions_formatter_patch.rb:21` `Redmine::WikiFormatting::Textile::Formatter::RULES` -> NameError. In R7 staat RULES op `Textile::Filter`. Hele app start niet. (`results/1006-084916-s1-redmine_wiki_extensions_origin_Redmine-5_1`; de harness print geen RESULT bij een boot-fail)

## 2. Upstream sync?   SYNC AANBEVOLEN
**Basiskeuze: Redmine-5.1 + merge van upstream main 1.3.0** (niet fork-main en niet Redmine-5.1 alleen). Waarom:
- Upstream 1.3.0 is de enige lijn die R7 al ondersteunt, met de juiste Textile-fix (Filter::RULES, c1ae91f/b08e436). Fork-main mist die (1.1.0) en zou de eigen GEOxyz-commits alsnog moeten krijgen.
- Redmine-5.1 alleen mist de upstream-fixes: footnote-XSS (3413f67, `title="...description..."` niet ge-escaped), ApplicationRecord (bad8c5d), core-TableSort i.p.v. jquery.tablesorter (#49, 65f99bb), view_wiki_pages-check in het projectmenu (ae435fe), video_tag met 3 args (in de eigen versie `args[3]` nil -> crash; upstream `>= 4`).
- De `claude/redmine7-rails8-compat`-guard laat de app booten, maar laat Textile-emoticons stil wegvallen. Gemeten: `to_html("textile", "Smile :) here")` -> `<p>Smile :) here</p>` (claude-branch) vs `<img src="/wiki_extentions/emoticon/smile.png" ...>` (migratiebranch).
- Merge 9505dfe -> Redmine-5.1: 28 conflict-hunks in 11 bestanden, vooral rubocop-stijl (quotes, spaties). Opgelost: stijlconflicten = upstream. Routes = GEOxyz (expliciet, geen dynamisch `:action`-segment; upstream geeft "removed in Rails 9.0"-deprecation). Settings-controller = upstream + GEOxyz `tag_dropdown_options`. init.rb = upstream 1.3.0 + GEOxyz-settings. Formatter = upstream Filter/Formatter-detectie + GEOxyz CommonMark-emoticonfilter + url_helpers op render-tijd (46ffc27).
- GEOxyz-commits overleven: tag-dropdown-setting + migratie 0015 (alleen GEOxyz; upstream stopt bij 0014, een toekomstige upstream-0015 botst), taglist-macro's, emoticon-route, CommonMark-emoticons, expliciete routes. De `to_prepare { WikiExtensionsProjectsHelperPatch.apply }` van upstream blijft weg: die methode bestaat niet.
- Nieuwe ZIP-export van alle wikipagina's (R7 #43978): geen overlap, de plugin heeft geen export.

## 3. Werkt na sync op Redmine 7?   JA (met eigen fixes)
- Harness `r70/trial-upstream`: boot OK (1.3.0), eager OK, migraties OK, smoke 66/66. WARN `/images/add.png` 404 (zie 4). minitest: `cannot load such file -- shoulda`. De tests vragen gems `shoulda` en `simplecov-lcov`, die niet in Redmine en niet in een plugin-Gemfile staan (geldt ook voor upstream en Redmine-5.1).
- Handmatig met tijdelijke `Gemfile.local` (shoulda, simplecov-lcov) + shim voor `Rails::TestUnitReporter#executable` (shoulda-context 2.0 crasht anders bij de eerste failure op Rails 8.1): trial = 56 runs, 1 failure, 24 errors. De 24 errors zijn allemaal `undefined method 'wiki_extensions_stylesheet_path'` -> bug uit GEOxyz-commit ff3dba7 (zit ook in productie 5.1 zodra een project een wikipagina "StyleSheet" heeft). Gefixt, zie 4.
- Ter vergelijking draaien upstream 9505dfe en de claude-branch ook: boot OK, smoke 61/61, met 2x deprecation "dynamic :action segment".

## 4. Complexiteit en blokkers   score 3
- Blokkers:
  - `lib/wiki_extensions_formatter_patch.rb:21` - RULES NameError - opgelost via upstream-merge (2e5cfcd).
  - `config/routes.rb:24` (ff3dba7) - routehelper hernoemd naar `project_wiki_extensions_stylesheet`, maar `_html_header.html.erb:27` roept `wiki_extensions_stylesheet_path` aan -> NameError op elke wikipagina van een project met een StyleSheet-pagina - gefixt in deb638a (route buiten de scope, oude naam terug).
  - `app/views/wiki_extensions/_tags_form.html.erb:23` - `image_tag("/images/add.png")` 404 sinds Propshaft - gefixt in 480e588 (`image_tag("add.png")`, gemeten: `/assets/add-f7d48fbc.png`, geladen).
- Stille breuken / bevindingen (open):
  - Twee GEOxyz-tests zijn fout geschreven (niet R7-gerelateerd, niet aangepast): `test/unit/wiki_extensions_setting_test.rb:52` - de fixture heeft twee settings-rijen voor project 1 en `find_by(project_id:)` is op PostgreSQL niet deterministisch na een update. `test/functional/wiki_controller_test.rb:136` (842d27f) verwacht `"MyString (2)"`, terwijl de macro altijd `"MyString(N)"` schrijft (ook op Redmine-5.1).
  - CommonMark: `{{comment_form}}` rendert via `@_controller.render_to_string` (`lib/wiki_extensions_comments.rb:35`), waardoor `heads_for_wiki_formatter` zijn `content_for` verliest -> JS-fout "jsToolBar is not defined" en geen toolbar in het commentaarformulier. Commentaar opslaan werkt wel (gemeten). Zelfde mechanisme als op 5.1, dus waarschijnlijk niet nieuw.
  - Deprecation: `app/models/wiki_extensions_comment.rb:41` `acts_as_activity_provider scope: select(...)` moet een proc worden (waarschuwing in R7, breekt later).
  - XSS (bestaand, niet gefixt): `_tags_form.html.erb` zet `tags[i].name` raw in `value="..."`.
- `fix/emoticon-commonmark-encoding` (e836b81, UTF-8-cast van de CommonMark-output) is op R7 niet nodig. Gemeten op de migratiebranch: `to_html('common_mark', "Smile :) hallo → wereld, à ë ü")` geeft UTF-8 (valid), emoticon-img gezet, multibyte-tekens intact. De route- en url_helpers-delen van die branch zitten al in 46ffc27.
- Macro-rendering op R7 (browser, wikipagina met macro's, CommonMark én Textile): emoticons `:)`/`:(` -> img via `/wiki_extentions/emoticon/*.png` (geladen). `{{fn}}`/`{{fnlist}}` met ge-escapete titel (`<b>` komt niet als HTML door). `div_start_tag` met id/class/style, `video_tag` met 3 en 4 args, `recent`, `count`, `new`, `lastupdated_at/by`, `project`, `tags`, `taglist`, `taggedpages`, `tagcloud`, `vote/show_vote`, `wiki`, `comments`, `comment_form`: alles gerenderd, geen 500. Projectinstellingen-tab zichtbaar, opslaan van tag_dropdown_options werkt ("Successful update.").
- Overlap met Redmine 7 core: geen ZIP-export. Gedeeltelijk: CommonMark-footnotes `[^1]` in core naast `{{fn}}`; core-TableSort (de plugin gebruikt die nu zelf).
- Open werk voor ansif:
  1. Testafhankelijkheden vastleggen (plugin-Gemfile met `shoulda`, `simplecov-lcov` in group :test, of tests omzetten). shoulda-context 2.0 is niet compatibel met de Rails 8.1-reporter.
  2. De twee GEOxyz-tests repareren (fixture met unieke project_id, verwachte tekst "MyString(N)").
  3. comment_form-toolbar op CommonMark (render in dezelfde view i.p.v. `render_to_string`, of jstoolbar expliciet laden).
  4. `acts_as_activity_provider scope:` naar een proc.
  5. Migratienummer 0015 is GEOxyz-eigen. Bij een volgende upstream-sync controleren op een botsing.

## Branch redmine70-migration
- Basis: origin/Redmine-5.1 @ e0b64b3 + merge upstream 9505dfe (--no-ff, conflicten opgelost)
- Commits: 2e5cfcd Merge upstream haru/redmine_wiki_extensions main (9505dfe) for Redmine 7 · deb638a Restore the wiki_extensions_stylesheet route name · 480e588 Load the tag form's add icon through the asset pipeline
- Eindresultaat harness (`results/1006-091759-s1-redmine_wiki_extensions_redmine70-migration`): boot OK (1.3.0), eager OK, migraties OK, rollback OK, smoke 66/66 (add.png-WARN weg), FAIL minitest = ontbrekende gem `shoulda` (omgeving). Handmatig met shoulda: **56 runs, 122 assertions, 2 failures, 0 errors** (de 2 foute GEOxyz-tests hierboven).
- Rollback migraties: OK

