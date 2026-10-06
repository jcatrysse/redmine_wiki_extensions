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

# The explicit routes that replaced the deprecated dynamic :action segment.
class WikiExtensionsRoutingTest < Redmine::RoutingTest
  def test_wiki_extensions_routes
    should_route "GET /wiki_extentions/emoticon/smile" => "wiki_extensions#emoticon", icon_name: "smile"
    should_route "GET /projects/foo/wiki_extensions/stylesheet" => "wiki_extensions#stylesheet", id: "foo"
    should_route "POST /projects/foo/wiki_extensions/vote" => "wiki_extensions#vote", id: "foo"
    should_route "POST /projects/foo/wiki_extensions/add_comment" => "wiki_extensions#add_comment", id: "foo"
    should_route "POST /projects/foo/wiki_extensions/reply_comment" => "wiki_extensions#reply_comment", id: "foo"
    should_route "POST /projects/foo/wiki_extensions/update_comment" => "wiki_extensions#update_comment", id: "foo"
    should_route "GET /projects/foo/wiki_extensions/forward_wiki_page" => "wiki_extensions#forward_wiki_page", id: "foo"
    should_route "GET /projects/foo/wiki_extensions/tag" => "wiki_extensions#tag", id: "foo"
  end

  def test_wiki_extensions_settings_routes
    should_route "GET /projects/foo/wiki_extensions_settings" => "wiki_extensions_settings#show", id: "foo"
    should_route "POST /projects/foo/wiki_extensions_settings" => "wiki_extensions_settings#update", id: "foo"
    should_route "PATCH /projects/foo/wiki_extensions_settings" => "wiki_extensions_settings#update", id: "foo"
  end
end
