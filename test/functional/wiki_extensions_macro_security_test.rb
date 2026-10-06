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

# Macros must not reveal what the viewer may not see, and must not turn
# their arguments into markup.
class WikiExtensionsMacroSecurityTest < ActionController::TestCase
  tests WikiController
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
    :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
    :wiki_extensions_tags, :wiki_extensions_tag_relations, :wiki_extensions_settings

  def setup
    EnabledModule.create!(project_id: 1, name: "wiki_extensions")
    @wiki = Project.find(1).wiki
    @page = @wiki.find_or_new_page("macro_security")
    @page.content = WikiContent.new(text: "test", author_id: 1)
    @page.save!
    # project 2 (onlinestore) is private; dlopper (user 3) is not a member
    @secret = WikiPage.find(3) # Start_page of project 2
  end

  def show(text, user_id)
    @page.content.text = text
    @page.content.save!
    @request.session[:user_id] = user_id
    get :show, params: { project_id: 1, id: @page.title }
    assert_response :success
  end

  def test_project_macro_hides_an_invisible_project
    show("{{project(onlinestore)}}", 3)
    assert_select "#content a[href=?]", "/projects/onlinestore", 0
    assert_not_includes response.body, "OnlineStore"

    show("{{project(onlinestore)}}", 1)
    assert_select "#content a[href=?]", "/projects/onlinestore", text: "OnlineStore"
  end

  def test_wiki_macro_hides_an_invisible_page
    show("{{wiki(onlinestore, Start_page, look here)}}", 3)
    assert_select "#content a[href=?]", "/projects/onlinestore/wiki/Start_page", 0

    show("{{wiki(onlinestore, Start_page, look here)}}", 1)
    assert_select "#content a[href=?]", "/projects/onlinestore/wiki/Start_page", text: "look here"
  end

  def test_lastupdated_at_macro_hides_an_invisible_page
    show("{{lastupdated_at(onlinestore, Start_page)}}", 3)
    assert_select "span.wiki_extensions_lastupdated_at", 0

    show("{{lastupdated_at(onlinestore, Start_page)}}", 1)
    assert_select "span.wiki_extensions_lastupdated_at"
  end

  def test_taggedpages_macro_lists_only_visible_pages
    @page.set_tags("0" => "shared")
    @secret.set_tags("0" => "shared")
    show("{{taggedpages(shared, project=all)}}", 3)
    assert_select "ul.wikiext-taggedpages a[href=?]", "/projects/ecookbook/wiki/Macro_security"
    assert_select "ul.wikiext-taggedpages a[href=?]", "/projects/onlinestore/wiki/Start_page", 0

    show("{{taggedpages(shared, project=all)}}", 1)
    assert_select "ul.wikiext-taggedpages a[href=?]", "/projects/onlinestore/wiki/Start_page"
  end

  def test_footnote_word_is_escaped
    show("A{{fn(<img src=x onerror=alert(1)>, the description)}}\n", 1)
    assert_select "img[onerror]", 0
    assert_includes response.body, "&lt;img src=x onerror=alert(1)&gt;"
  end

  def test_iframe_attributes_are_escaped
    show(%({{iframe(https://example.com/x, 100" onload="alert(1), 50)}}), 1)
    assert_select "iframe[src=?]", "https://example.com/x"
    assert_select "iframe[onload]", 0
  end
end
