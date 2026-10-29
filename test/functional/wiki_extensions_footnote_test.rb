# Wiki Extensions plugin for Redmine
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

# Footnotes of text without a wiki page (previews, project descriptions)
# belong to one render: never to the next request, never to another thread.
class WikiExtensionsFootnoteTest < ActionController::TestCase
  tests PreviewsController
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
    :trackers, :projects_trackers, :issue_statuses, :enumerations,
    :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions

  FNLIST = '<div class="wiki_extensions_fnlist"><hr/>' + "\n" + "<ul>" +
    '<li><span class="wiki_extensions_fn">*1</span> <a name="wiki_extensins_fn_1" href="#wiki_extensins_fn_src_1">aaa</a>:bbb</li>' +
    '<li><span class="wiki_extensions_fn">*2</span> <a name="wiki_extensins_fn_2" href="#wiki_extensins_fn_src_2">ccc</a>:ddd</li>' +
    "</ul></div>"
  FN1 = 'aaa<a href="#wiki_extensins_fn_1" class="wiki_extensions_fn" title="bbb" name="wiki_extensins_fn_src_1">*1</a>'
  FN2 = 'ccc<a href="#wiki_extensins_fn_2" class="wiki_extensions_fn" title="ddd" name="wiki_extensins_fn_src_2">*2</a>'
  TEXT = "{{fn(aaa,bbb)}}\n\n{{fn(ccc,ddd)}}\n\n{{fnlist}}\n"

  def setup
    EnabledModule.create!(project_id: 1, name: "wiki_extensions")
    @request.session[:user_id] = 2
  end

  def preview(text)
    post :issue, params: { project_id: 1, text: text }
    assert_response :success
    response.body
  end

  def render_in(view, text)
    view.textilizable(text)
  end

  def new_view
    controller = PreviewsController.new
    controller.request = ActionDispatch::TestRequest.create
    view = controller.view_context
    view.instance_variable_set(:@project, @project)
    view
  end

  def test_previews_in_a_row_do_not_share_footnotes
    preview("{{fn(first, left over)}}\n")
    body = preview("{{fn(second, mine)}}\n\n{{fnlist}}\n")
    assert_not_includes body, "left over"
    assert_select "div.wiki_extensions_fnlist li", 1
    assert_select "a.wiki_extensions_fn[href=?]", "#wiki_extensins_fn_1", text: "*1"
  end

  def test_threads_rendering_at_the_same_time_keep_their_own_footnotes
    @project = Project.find(1)
    assert @project.module_enabled?("wiki_extensions")
    alpha_rendered = Queue.new
    beta_rendered = Queue.new
    alpha = Thread.new do
      view = new_view
      render_in(view, "{{fn(alpha, alpha secret)}}\n")
      alpha_rendered << true
      beta_rendered.pop
      render_in(view, "{{fnlist}}\n")
    end
    beta = Thread.new do
      alpha_rendered.pop
      result = render_in(new_view, "{{fn(beta, beta note)}}\n\n{{fnlist}}\n")
      beta_rendered << true
      result
    end
    alpha_list = alpha.value
    beta_list = beta.value

    assert_not_includes beta_list, "alpha secret"
    assert_includes beta_list, ">beta</a>:beta note</li>"
    assert_includes beta_list, ">*1</a>"
    assert_not_includes alpha_list, "beta note"
    assert_includes alpha_list, ">alpha</a>:alpha secret</li>"
  end

  def test_fnlist_of_a_preview_is_unchanged
    body = preview(TEXT)
    assert_includes body, FN1
    assert_includes body, FN2
    assert_includes body, FNLIST
  end

  def test_fnlist_of_a_wiki_preview_is_unchanged
    @controller = WikiController.new
    post :preview, params: { project_id: 1, id: "New_footnote_page", content: { text: TEXT } }
    assert_response :success
    assert_includes response.body, FNLIST
    post :preview, params: { project_id: 1, id: "New_footnote_page", content: { text: TEXT } }
    assert_includes response.body, FNLIST
  end

  def test_fnlist_of_a_wiki_page_is_unchanged
    @controller = WikiController.new
    page = Project.find(1).wiki.find_page("Another_page")
    page.content.text = "{{fn(aaa,bbb)}}\n\n{{fn(ccc,ddd)}}\n"
    page.content.save!
    get :show, params: { project_id: 1, id: page.title }
    assert_response :success
    assert_includes response.body, FN1
    assert_includes response.body, FN2
    assert_includes response.body, FNLIST
  end
end
