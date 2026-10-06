# Wiki Extensions plugin for Redmine
# Copyright (C) 2009-2010  Haruyuki Iida
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

class WikiExtensionsCommentTest < ActiveSupport::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules,
    :wikis, :wiki_pages, :wiki_contents, :wiki_extensions_comments

  # Replace this with your real tests.
  def test_truth
    assert true
  end
  def test_activity_provider_lists_comments_without_deprecation
    comment = WikiExtensionsComment.create!(wiki_page_id: 1, user_id: 2, comment: "activity check")
    fetcher = Redmine::Activity::Fetcher.new(User.find(1), project: Project.find(1))
    fetcher.scope = ["wiki_comment"]
    events = nil
    assert_not_deprecated(Rails.application.deprecators[:redmine]) do
      events = fetcher.events(Time.zone.today - 1, Time.zone.today + 1)
    end
    # the provider scope selects a few columns only (no id), so compare those
    assert_includes events.map { |e| [e.wiki_page_id, e.user_id, e.comment] }, [1, 2, "activity check"]
    assert_equal "Wiki comment: CookBook_documentation", comment.event_title
  end

  def test_activity_provider_respects_view_wiki_edits
    WikiExtensionsComment.create!(wiki_page_id: 1, user_id: 2, comment: "hidden check")
    Role.anonymous.remove_permission!(:view_wiki_edits)
    fetcher = Redmine::Activity::Fetcher.new(User.anonymous, project: Project.find(1))
    fetcher.scope = ["wiki_comment"]
    assert_empty fetcher.events(Time.zone.today - 1, Time.zone.today + 1)
  end
end
