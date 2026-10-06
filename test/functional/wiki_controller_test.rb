# Code Review plugin for Redmine
# Copyright (C) 2009-2017  Haruyuki Iida
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
require File.dirname(__FILE__) + "/../test_helper"

class WikiControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :enabled_modules, :wikis,
    :wiki_pages, :wiki_contents, :wiki_content_versions, :attachments,
    :wiki_extensions_comments, :wiki_extensions_tags

  def setup
    @controller = WikiController.new
    @request = ActionController::TestRequest.create(self.class.controller_class)
    # @response   = ActionController::TestResponse.new
    @request.env["HTTP_REFERER"] = "/"
    @project = Project.find(1)
    @wiki = @project.wiki
    @page_name = "macro_test"
    @page = @wiki.find_or_new_page(@page_name)
    @page.content = WikiContent.new
    @page.content.text = "test"
    @page.save!
    side_bar = @wiki.find_or_new_page("SideBar")
    side_bar.content = WikiContent.new
    side_bar.content.text = "test"
    side_bar.save!
    header = @wiki.find_or_new_page("Header")
    header.content = WikiContent.new
    header.content.text = "test"
    header.save!
    footer = @wiki.find_or_new_page("Footer")
    footer.content = WikiContent.new
    footer.content.text = "test"
    footer.save!
    style_sheet = @wiki.find_or_new_page("StyleSheet")
    style_sheet.content = WikiContent.new
    style_sheet.content.text = "test"
    style_sheet.save!
    enabled_module = EnabledModule.new
    enabled_module.project_id = 1
    enabled_module.name = "wiki_extensions"
    enabled_module.save
  end

  def test_comment_form
    text = "{{comment_form}}"
    text << "\n"
    text << "{{comments}}"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_comment_form_loads_the_wiki_toolbar
    with_settings text_formatting: "common_mark" do
      setContent("{{comment_form}}")
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
      assert_select "form[action=?] textarea.wiki-edit[name=comment]", "/projects/ecookbook/wiki_extensions/add_comment"
      # the toolbar script draws new jsToolBar(...); its library must be in the head
      assert_select "script", text: /new jsToolBar\(document.getElementById\('add_comment_area_\d+'\)\)/
      assert_select "head script[src*=?]", "jstoolbar/jstoolbar"
    end
  end

  def test_comment_form_in_pdf_export
    setContent("{{comment_form}}\n\ntext")
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name, format: "pdf" }
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  def test_comment_form_hidden_without_permission
    Role.anonymous.remove_permission!(:add_wiki_comment)
    setContent("{{comment_form}}")
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select "textarea[name=comment]", 0
  end

  def test_comments
    text = "{{comments}}"
    setContent(text)
    comment = WikiExtensionsComment.new
    comment.wiki_page_id = @page.id
    comment.user_id = 1
    comment.comment = "aaa"
    comment.save!
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    # deleting is a DELETE request with a confirmation, never a plain link
    assert_select "a.icon-del[href=?][data-method=delete][data-confirm]",
                  "/projects/ecookbook/wiki_extensions/destroy_comment?comment_id=#{comment.id}"
  end

  def test_comment_edit_and_delete_links_only_for_author_or_admin
    Role.find(2).add_permission!(:add_wiki_comment, :edit_wiki_comments, :delete_wiki_comments)
    setContent("{{comments}}")
    other = WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 2, comment: "by jsmith")
    own = WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 3, comment: "by dlopper")
    @request.session[:user_id] = 3 # dlopper, Developer of project 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    # the actions also require being the author or an admin, so the links follow that
    assert_select "#wikiextensions_comment_li_#{other.id} > div.contextual a.icon-edit", 0
    assert_select "#wikiextensions_comment_li_#{other.id} > div.contextual a.icon-del", 0
    assert_select "#wikiextensions_comment_li_#{other.id} > div.contextual a.icon-comment"
    assert_select "#wikiextensions_comment_li_#{own.id} > div.contextual a.icon-edit"
    assert_select "#wikiextensions_comment_li_#{own.id} > div.contextual a.icon-del"
  end

  def test_comment_links_for_the_author_need_the_permissions
    Role.find(2).remove_permission!(:edit_wiki_comments, :delete_wiki_comments)
    setContent("{{comments}}")
    own = WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 3, comment: "by dlopper")
    @request.session[:user_id] = 3
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select "#wikiextensions_comment_li_#{own.id} > div.contextual a.icon-edit", 0
    assert_select "#wikiextensions_comment_li_#{own.id} > div.contextual a.icon-del", 0
  end

  def test_comments_escape_the_author_name
    user = User.find(2)
    user.update_column(:firstname, "<b>bold</b>")
    setContent("{{comments}}")
    WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 2, comment: "hello")
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select "h4.wiki_left b", 0
    assert_select "h4.wiki_left", text: /<b>bold<\/b> Smith/
  end

  def test_div
    @request.session[:user_id] = 1
    text = "{{div_start_tag(foo)}}\n"
    text << "{{div_end_tag}}\n"
    text << "{{div_start_tag(var, hoge)}}\n"
    text << "{{div_end_tag}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_footnote
    text = "{{fn(aaa,bbb)}}\n"
    text << "{{fn(ccc,ddd)}}\n"
    text << "{{fnlist}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_new
    text = "{{new(#{Time.zone.today})}}\n"
    text << "{{new(#{(Time.zone.today - 1)})}}\n"
    text << "{{new(#{(Time.zone.today - 2)})}}\n"
    text << "{{new(2009-03-01, 4)}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_project
    text = "{{project(#{@project.name})}}\n"
    text << "{{project(#{@project.id})}}\n"
    text << "{{project(#{@project.name}, hoge)}}\n"
    text << "{{project(#{@project.id}), bar}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_tags
    page = @wiki.find_or_new_page(@page_name)
    page.wiki_ext_tags << WikiExtensionsTag.find(1)
    page.save!
    text = "{{tags}}\n"
    text << "{{tagcloud}}\n"
    text << "{{taglist}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    count = WikiExtensionsTag.find(1).page_count
    assert_operator count, :>, 0
    # the macros write "name(count)", without a space
    assert_includes response.body, "MyString(#{count})"
    assert_includes response.body, "MyString2(0)"
  end

  def test_taglist_variants
    page = @wiki.find_or_new_page(@page_name)
    page.wiki_ext_tags << WikiExtensionsTag.find(1)
    page.save!
    count = WikiExtensionsTag.find(1).page_count
    link1 = %r{<a href="/projects/ecookbook/wiki_extensions/tag\?tag_id=1">MyString\(#{count}\)</a>}
    link2 = %r{<a href="/projects/ecookbook/wiki_extensions/tag\?tag_id=2">MyString2\(0\)</a>}
    @request.session[:user_id] = 1

    setContent("{{taglist}}\n")
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_match(/#{link1}<br\/>\n#{link2}/, response.body)

    setContent("{{taglist_commas}}\n")
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_match(/#{link1}, #{link2}/, response.body)

    setContent("{{taglist_bullets}}\n")
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_match(/<ul>\n<li>#{link1}<\/li>\n<li>#{link2}<\/li>\n<\/ul>/, response.body)
  end

  def test_wiki
    text = ""
    text << "{{wiki(#{@project.name}, #{@page_name})}}\n"
    text << "{{wiki(#{@project.name}, #{@page_name}, foo)}}\n"
    text << "{{wiki(#{@project.id}, #{@page_name})}}\n"
    text << "{{wiki(#{@project.id}, #{@page_name}, bar)}}\n"
    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_edit
    @request.session[:user_id] = 1
    get :edit, params: { project_id: 1, id: @page_name }
    assert_response :success

    post :edit, params: { project_id: 1, id: @page_name, content: { text: "aaa" },
                             extension: { tags: { "0" => "aaa", "1" => "bbb" } } }
    assert_response :success
  end

  def test_edit_keeps_a_first_tag_that_is_not_a_dropdown_option
    page = @wiki.find_page(@page_name)
    page.set_tags("0" => "alpha", "1" => "approved")
    @request.session[:user_id] = 1
    get :edit, params: { project_id: 1, id: @page_name }
    assert_response :success
    # the first (alphabetical) tag goes into the dropdown; it must stay selected
    # or saving the page would silently drop it
    assert_select "select[name=?]", "extension[tags][0]" do
      assert_select "option[selected][value=?]", "alpha"
      assert_select "option[value=?]", "approved"
    end
    assert_select "input[name=?][value=?]", "extension[tags][1]", "approved"
  end

  def test_edit_escapes_tag_names_in_the_tag_fields
    page = @wiki.find_page(@page_name)
    page.set_tags("0" => "a", "1" => 'b" onfocus="alert(1)')
    @request.session[:user_id] = 1
    get :edit, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_select "input[name=?][value=?]", "extension[tags][1]", 'b" onfocus="alert(1)'
    assert_select "input[onfocus]", 0
  end

  def test_edit_escapes_tag_names_in_the_autocomplete_list
    page = @wiki.find_page(@page_name)
    page.set_tags("0" => "a", "1" => "it's</script><script>alert(1)//")
    @request.session[:user_id] = 1
    get :edit, params: { project_id: 1, id: @page_name }
    assert_response :success
    assert_includes response.body, %q(= 'it\'s<\/script><script>alert(1)//';)
    assert_not_includes response.body, "</script><script>alert(1)"
  end

  def test_recent
    text = ""
    text << "{{recent}}\n"
    text << "{{recent(10)}}\n"

    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_lastupdated_by
    text = ""
    text << "{{lastupdated_by}}\n"

    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_lastupdated_at
    text = ""
    text << "{{lastupdated_at}}\n"

    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  def test_iframe
    text = ""
    text << "{{iframe(http://google.com, 200, 400)}}\n"
    text << "{{iframe(http://google.com, 200, 400, no)}}\n"

    setContent(text)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_response :success
  end

  context "count" do
    should "success" do
      @request.session[:user_id] = 1
      text = ""
      text << "{{count}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  def test_count_once_per_session_after_a_json_round_trip
    setContent("{{count}}{{show_count}}")
    page = @wiki.find_page(@page_name)
    @request.session[:user_id] = 1
    get :show, params: { project_id: 1, id: @page_name }
    assert_equal 1, WikiExtensionsCount.access_count(page.id)
    # Redmine 7 keeps sessions as JSON: integer hash keys come back as strings
    @request.session[:access_count_table] = JSON.parse(@request.session[:access_count_table].to_json)
    get :show, params: { project_id: 1, id: @page_name }
    assert_equal 1, WikiExtensionsCount.access_count(page.id)
  end

  context "show_count" do
    should "success" do
      text = ""
      text << "{{show_count}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  context "popularity" do
    should "success if there is no count data" do
      text = ""
      text << "{{popularity}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end

    should "success if there is count data" do
      text = ""
      text << "{{count}}\n"
      text << "{{popularity}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  context "vote" do
    should "success" do
      text = ""
      text << "{{vote(aaa)}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
      # the vote route only accepts POST; jQuery's load() posts when it gets data
      assert_select "span.wikiext-vote a[onclick*=?]", "/projects/ecookbook/wiki_extensions/vote?"
      assert_select "span.wikiext-vote a[onclick*=?]", "', {})"
    end
  end

  context "show_vote" do
    should "success" do
      text = ""
      text << "{{show_vote(aaa)}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  context "twitter" do
    should "success" do
      text = ""
      text << "{{twitter(haru_iida)}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  context "taggedpages" do
    should "success" do
      text = ""
      text << "{{taggedpages(aaa)}}\n"

      setContent(text)
      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
      assert_response :success
    end
  end

  context "page_break" do
    setup do
      setContent("{{page_break}}\n")

      @request.session[:user_id] = 1
      get :show, params: { project_id: 1, id: @page_name }
    end

    should "success" do
      assert_response :success
    end

    should "be rendered correctly" do
      assert response.body.include?('<div class="wikiext-page-break">')
    end
  end

  private

  def setContent(text)
    page = @wiki.find_or_new_page(@page_name)
    page.content.text = text
    page.content.author_id = 1
    page.save!
    page.content.save!
  end
end
