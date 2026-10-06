# Wiki Extensions plugin for Redmine
# Copyright (C) 2009-2019  Haruyuki Iida
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

class WikiExtensionsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :enabled_modules, :wikis,
    :wiki_pages, :wiki_contents, :wiki_content_versions, :attachments,
    :wiki_extensions_comments, :wiki_extensions_tags, :wiki_extensions_menus,
    :wiki_extensions_votes

  def setup
    @controller = WikiExtensionsController.new
    @request = ActionController::TestRequest.create(self.class.controller_class)
    # @response   = ActionController::TestResponse.new
    @request.env["HTTP_REFERER"] = "/"
    @project = Project.find(1)
    @wiki = @project.wiki
    @page_name = "macro_test"
    @page = @wiki.find_or_new_page(@page_name)
    @page.content = WikiContent.new
    @page.content.text = "{{comments}}"
    @page.save!
    side_bar = @wiki.find_or_new_page("SideBar")
    side_bar.content = WikiContent.new
    side_bar.content.text = "test"
    side_bar.save!
    style_sheet = @wiki.find_or_new_page("StyleSheet")
    style_sheet.content = WikiContent.new
    style_sheet.content.text = "test"
    style_sheet.save!
    enabled_module = EnabledModule.new
    enabled_module.project_id = 1
    enabled_module.name = "wiki_extensions"
    enabled_module.save
  end

  def test_add_comment
    @request.session[:user_id] = 1
    post :add_comment, params: { id: 1, wiki_page_id: @page.id, comment: "aaa" }
    assert_response :redirect
  end

  def test_tag
    @request.session[:user_id] = 1
    get :tag, params: { id: 1, tag_id: 1 }
    # assert assigns[:tag]
  end

  def test_destroy_comment
    comment = WikiExtensionsComment.new
    comment.wiki_page_id = @page.id
    comment.user_id = 1
    comment.comment = "aaa"
    comment.save!
    @request.session[:user_id] = 1
    post :destroy_comment, params: { id: 1, comment_id: comment.id }
    assert_response :redirect
    comment = WikiExtensionsComment.where(id: comment.id).first
    assert_nil(comment)
  end

  def test_update_comment
    comment = WikiExtensionsComment.new
    comment.wiki_page_id = @page.id
    comment.user_id = 1
    comment.comment = "aaa"
    comment.save!
    message = "newcomment"
    @request.session[:user_id] = 1
    post :update_comment, params: { id: 1, comment_id: comment.id, comment: message }
    assert_response :redirect
    comment = WikiExtensionsComment.find(comment.id)
    assert_equal(message, comment.comment)
  end

  def test_forwad_wiki_page
    @request.session[:user_id] = 1
    get :forward_wiki_page, params: { id: 1, menu_id: 1 }
    assert_response :redirect
  end

  def test_stylesheet
    @project.is_public = false
    @project.save!
    get :stylesheet, params: { id: 1 }
    assert_response :forbidden

    @request.session[:user_id] = 1
    get :stylesheet, params: { id: 1 }
    assert_response :success

    get :stylesheet, params: { id: 2 }
    assert_response :not_found
  end

  context "vote" do
    should "success if new vote." do
      @request.session[:user_id] = 1
      count = WikiExtensionsVote.all.length
      post :vote, params: { id: 1, target_class_name: "Project", target_id: 1,
                               key: "aaa", url: "http://localhost:3000" }
      assert_equal(count + 1, WikiExtensionsVote.all.length)
      assert_response :success
    end
  end
  # dlopper (user 3) is a Developer of project 1 only; project 2 is private
  def grant_comment_permissions
    Role.find(2).add_permission!(:add_wiki_comment, :edit_wiki_comments, :delete_wiki_comments)
    @request.session[:user_id] = 3
  end

  def foreign_comment(user_id = 3)
    WikiExtensionsComment.create!(wiki_page_id: 3, user_id: user_id, comment: "on a private page")
  end

  def test_add_comment_refuses_a_page_of_another_project
    grant_comment_permissions
    assert_no_difference "WikiExtensionsComment.count" do
      post :add_comment, params: { id: 1, wiki_page_id: 3, comment: "sneaky" }
    end
    assert_response :not_found
  end

  def test_reply_comment_refuses_a_page_of_another_project
    grant_comment_permissions
    parent = foreign_comment
    assert_no_difference "WikiExtensionsComment.count" do
      post :reply_comment, params: { id: 1, wiki_page_id: 3, comment_id: parent.id, reply: "sneaky" }
    end
    assert_response :not_found
  end

  def test_reply_comment_refuses_a_parent_on_another_page
    grant_comment_permissions
    parent = foreign_comment
    assert_no_difference "WikiExtensionsComment.count" do
      post :reply_comment, params: { id: 1, wiki_page_id: @page.id, comment_id: parent.id, reply: "sneaky" }
    end
    assert_response :not_found
  end

  def test_reply_comment
    grant_comment_permissions
    parent = WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 1, comment: "parent")
    post :reply_comment, params: { id: 1, wiki_page_id: @page.id, comment_id: parent.id, reply: "child" }
    assert_redirected_to "/projects/ecookbook/wiki/#{@page.title}"
    assert_equal parent.id, WikiExtensionsComment.order(:id).last.parent_id
  end

  def test_update_comment_refuses_a_comment_of_another_project
    grant_comment_permissions
    comment = foreign_comment
    post :update_comment, params: { id: 1, comment_id: comment.id, comment: "changed" }
    assert_response :not_found
    assert_equal "on a private page", comment.reload.comment
  end

  def test_destroy_comment_refuses_a_comment_of_another_project
    grant_comment_permissions
    comment = foreign_comment
    delete :destroy_comment, params: { id: 1, comment_id: comment.id }
    assert_response :not_found
    assert WikiExtensionsComment.exists?(comment.id)
  end

  def test_update_comment_of_another_user_is_refused
    grant_comment_permissions
    comment = WikiExtensionsComment.create!(wiki_page_id: @page.id, user_id: 2, comment: "by jsmith")
    post :update_comment, params: { id: 1, comment_id: comment.id, comment: "changed" }
    assert_response :forbidden
    assert_equal "by jsmith", comment.reload.comment
  end
  def test_add_comment_notifies_watchers
    @page.add_watcher(User.find(2))
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    with_settings notified_events: %w(wiki_comment_added) do
      post :add_comment, params: { id: 1, wiki_page_id: @page.id, comment: "watched" }
    end
    assert_response :redirect
    mail = ActionMailer::Base.deliveries.detect { |m| m.to.include?("jsmith@somenet.foo") }
    assert mail
    assert_match(/commented/, mail.subject)
  end

  def test_add_comment_with_empty_text_saves_and_sends_nothing
    @page.add_watcher(User.find(2))
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    with_settings notified_events: %w(wiki_comment_added) do
      assert_no_difference "WikiExtensionsComment.count" do
        post :add_comment, params: { id: 1, wiki_page_id: @page.id, comment: "" }
      end
    end
    assert_redirected_to "/projects/ecookbook/wiki/#{@page.title}"
    assert_equal "Comment cannot be blank", flash[:error]
    assert_empty ActionMailer::Base.deliveries
  end
  def test_tag_lists_the_tagged_pages
    @page.set_tags("0" => "listed")
    tag = WikiExtensionsTag.find_by(project_id: 1, name: "listed")
    @request.session[:user_id] = 2
    get :tag, params: { id: 1, tag_id: tag.id }
    assert_response :success
    assert_select "#content a[href=?]", "/projects/ecookbook/wiki/#{@page.title}"
  end

  def test_tag_of_another_project_is_not_found
    page = WikiPage.find(3) # project 2 (private)
    page.set_tags("0" => "secret-tag")
    tag = WikiExtensionsTag.find_by(project_id: 2, name: "secret-tag")
    @request.session[:user_id] = 3 # not a member of project 2
    get :tag, params: { id: 1, tag_id: tag.id }
    assert_response :not_found
    assert_not_includes response.body, page.title
  end
end
