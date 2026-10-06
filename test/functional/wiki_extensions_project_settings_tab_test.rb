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

# The "Wiki Extensions" tab on the project settings page (GEOxyz 5e60148,
# now through WikiExtensionsProjectsHelperPatch#project_settings_tabs).
class WikiExtensionsProjectSettingsTabTest < ActionController::TestCase
  tests ProjectsController
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
    :wikis, :wiki_extensions_settings, :wiki_extensions_menus

  def setup
    EnabledModule.create!(project_id: 1, name: "wiki_extensions")
    @role = Role.find(1) # jsmith (user 2) is Manager of project 1
  end

  def test_tab_shown_with_permission
    @role.add_permission!(:wiki_extensions_settings)
    @request.session[:user_id] = 2
    get :settings, params: { id: 1 }
    assert_response :success
    assert_select "#tab-wiki_extensions"
    assert_select "#tab-content-wiki_extensions textarea[name=?]", "setting[tag_dropdown_options]"
  end

  def test_tab_hidden_without_permission
    @role.remove_permission!(:wiki_extensions_settings)
    @request.session[:user_id] = 2
    get :settings, params: { id: 1 }
    assert_response :success
    assert_select "#tab-wiki_extensions", 0
  end

  def test_tab_hidden_when_module_disabled
    EnabledModule.where(project_id: 1, name: "wiki_extensions").delete_all
    @request.session[:user_id] = 1
    get :settings, params: { id: 1 }
    assert_response :success
    assert_select "#tab-wiki_extensions", 0
  end
end
