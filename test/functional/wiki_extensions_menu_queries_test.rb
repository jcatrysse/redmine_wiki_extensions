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

# The five project menu tabs must cost one query per page, not one or two per tab.
class WikiExtensionsMenuQueriesTest < ActionController::TestCase
  tests ProjectsController
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
    :wikis, :wiki_pages, :wiki_extensions_menus, :wiki_extensions_settings

  def setup
    EnabledModule.create!(project_id: 1, name: "wiki_extensions")
    @request.session[:user_id] = 1
  end

  def menu_queries
    sqls = []
    callback = ->(*, payload) { sqls << payload[:sql] if payload[:sql] =~ /wiki_extensions_menus/i }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    sqls
  end

  def test_one_query_for_the_menu_tabs
    sqls = menu_queries { get :show, params: { id: 1 } }
    assert_response :success
    assert_equal 1, sqls.size, sqls.join("\n")
    # behaviour unchanged: fixture tab 1 ("hoge") is enabled and shown
    assert_select "#main-menu a.wiki-extensions1", text: "hoge"
    assert_select "#main-menu a.wiki-extensions2", 0
  end

  def test_rendering_the_menu_creates_no_rows
    WikiExtensionsMenu.where(project_id: 1).where.not(menu_no: 1).delete_all
    assert_no_difference "WikiExtensionsMenu.count" do
      get :show, params: { id: 1 }
    end
    assert_select "#main-menu a.wiki-extensions1", text: "hoge"
  end

  def test_tab_with_page_but_no_title_shows_the_page_name
    menu = WikiExtensionsMenu.find_or_create(1, 3)
    menu.update!(enabled: true, title: "", page_name: "Another_page")
    get :show, params: { id: 1 }
    assert_select "#main-menu a.wiki-extensions3", text: "Another_page"
  end
end
