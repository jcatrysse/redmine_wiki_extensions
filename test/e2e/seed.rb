# Plugin data for the end-to-end scenarios in test/e2e/*.mjs. Run by
# .codex/start_server.sh with `rails runner` after the generic seed
# (.codex/e2e/seed.rb), whose users and projects it uses. Idempotent.

admin = User.find_by!(login: 'admin')
manager = User.find_by!(login: 'manager')
reporter = User.find_by!(login: 'reporter')
User.current = admin
project = Project.find_by!(identifier: 'e2e-project')
private_project = Project.find_by!(identifier: 'e2e-private')

# commenter: may comment in e2e-project (and nothing more), no membership in
# e2e-private; for the cross-project and other-author refusals.
commenter = User.find_by(login: 'commenter') ||
            User.new(login: 'commenter', firstname: 'Commenter', lastname: 'E2E', mail: 'commenter@example.net')
commenter.password = commenter.password_confirmation = ENV.fetch('RMP_USER_PASSWORD', ENV.fetch('RMP_ADMIN_PASSWORD', 'Redmine7Test!'))
commenter.must_change_passwd = false
commenter.status = User::STATUS_ACTIVE
commenter.save!(validate: false)
commenter_role = Role.find_by(name: 'E2E commenter') || Role.new(name: 'E2E commenter')
commenter_role.permissions = %i[view_wiki_pages view_wiki_edits add_wiki_comment edit_wiki_comments delete_wiki_comments]
commenter_role.save!
unless Member.where(user_id: commenter.id, project_id: project.id).exists?
  Member.create!(principal: commenter, project: project, roles: [commenter_role])
end

# Mail for new wiki comments (the notifiable this plugin adds).
Setting.notified_events = (Setting.notified_events + ['wiki_comment_added']).uniq

def e2e_page(project, title, text, author)
  wiki = project.wiki
  page = wiki.find_page(title) || WikiPage.new(wiki: wiki, title: title)
  if page.new_record?
    page.save_with_content(WikiContent.new(text: text, author: author))
  elsif page.content.text != text
    page.content.text = text
    page.content.author = author
    page.content.save!
  end
  page.reload
end

today = Date.today
# same origin as the server under test: cookies ignore the port, so a frame on
# another local Redmine would replace this one's session cookie
base = "http://127.0.0.1:#{ENV.fetch('RMP_PORT', '3000')}"
e2e_page(project, 'Macros', <<~TEXT, admin)
  # Macros

  **new**: {{new(#{today})}} {{new(#{today - 1})}} {{new(2009-03-01)}}

  **project**: {{project(e2e-project)}} / {{project(e2e-project, alias for the project)}}

  **wiki**: {{wiki(e2e-project, Macros, link to this page)}}

  **twitter**: {{twitter(redmine)}}

  **lastupdated_at**: {{lastupdated_at}} **lastupdated_by**: {{lastupdated_by}}

  **footnote**: Redmine{{fn(Redmine, a project management web application)}} and Rails{{fn(Rails, a web framework)}}

  {{div_start_tag(boxed, wikiext-e2e-box, style=border: 2px solid green; padding: 4px;)}}
  inside div_start_tag
  {{div_end_tag}}

  **count**: {{count}} views: {{show_count}}

  **popularity**: {{popularity(5)}}

  **recent**: {{recent(30)}}

  **page_break**: {{page_break}}

  **iframe**: {{iframe(#{base}/robots.txt, 300, 40)}}

  **video_tag**: {{video_tag(#{base}/missing.mp4, 160, 90)}}

  **new_page**: {{new_page}}
TEXT

comments_page = e2e_page(project, 'Comments', "# Comments\n\n{{comment_form}}\n\n{{comments}}\n", admin)
if WikiExtensionsComment.where(wiki_page_id: comments_page.id).none?
  first = WikiExtensionsComment.create!(wiki_page_id: comments_page.id, user_id: manager.id,
                                        comment: 'First comment, by the manager.')
  WikiExtensionsComment.create!(wiki_page_id: comments_page.id, user_id: admin.id, parent_id: first.id,
                                comment: 'A reply by the admin.')
end
comments_page.add_watcher(manager) unless comments_page.watched_by?(manager)

one = e2e_page(project, 'Tagged_one', "# Tagged one\n\n{{tags}}\n", admin)
one.set_tags('0' => 'approved', '1' => 'alpha')
two = e2e_page(project, 'Tagged_two', "# Tagged two\n\n{{tags}}\n", admin)
two.set_tags('0' => 'approved')
e2e_page(project, 'Tag_index', <<~TEXT, admin)
  # Tag index

  ## tagcloud
  {{tagcloud}}

  ## taglist
  {{taglist}}

  ## taglist_commas
  {{taglist_commas}}

  ## taglist_bullets
  {{taglist_bullets}}

  ## taggedpages(approved)
  {{taggedpages(approved)}}

  ## taggedpages(approved, alpha, project=e2e-project, operator=AND)
  {{taggedpages(approved, alpha, project=e2e-project, operator=AND)}}
TEXT

e2e_page(project, 'Vote', "# Vote\n\n{{vote(like, I like it)}}\n\nResult: {{show_vote(like)}}\n", admin)
e2e_page(project, 'Emoticons', "# Emoticons\n\nSmile :) sad :( tongue :P grin :D wink ;) check (/) cross (x) warning (!) end\n", admin)
e2e_page(project, 'Header', "Project header from the Header page", admin)
e2e_page(project, 'Footer', "Project footer from the Footer page", admin)
# CommonMark strips the id of the header wrapper div (core sanitizer), so the
# h1 rule is the one that shows the StyleSheet page applies there.
e2e_page(project, 'StyleSheet', "#wiki_extentions_header { border: 3px solid rgb(255, 0, 0); }\n" \
                                "#content div.wiki-page h1 { color: rgb(200, 0, 0); }\n", admin)

# Things a reader of e2e-project must not learn about e2e-private.
secret = e2e_page(private_project, 'Secret', "# Secret\n\nPrivate text.\n", admin)
secret.set_tags('0' => 'secret-tag')
e2e_page(private_project, 'StyleSheet', "body { background: rgb(0, 0, 255); }\n", admin)
e2e_page(project, 'Leaks', <<~TEXT, admin)
  # Leaks

  project: [{{project(e2e-private)}}]

  wiki: [{{wiki(e2e-private, Secret, the secret page)}}]

  lastupdated_at: [{{lastupdated_at(e2e-private, Secret)}}]

  taggedpages: [{{taggedpages(secret-tag, project=all)}}]
TEXT

# Markup in macro arguments and tag names must stay text.
unsafe = e2e_page(project, 'Unsafe', <<~TEXT, admin)
  # Unsafe

  footnote: X{{fn(<img src=x onerror=alert('fn')>, description)}}

  iframe: {{iframe(#{base}/robots.txt, 100" onload="alert('iframe'), 40)}}

  {{fnlist}}
TEXT
unsafe.set_tags('0' => 'approved', '1' => %q(x" onfocus="alert('tag')" autofocus="))

e2e_page(project, 'Errors', <<~TEXT, admin)
  # Errors

  iframe without url: {{iframe(not a url)}}

  new with a bad date: {{new(not-a-date)}}

  vote without a key: [{{vote}}]

  taggedpages without tags: [{{taggedpages}}]
TEXT

puts "Plugin seed: #{project.wiki.pages.count} pages in e2e-project, #{WikiExtensionsTag.count} tags, " \
     "#{WikiExtensionsComment.count} comments"
