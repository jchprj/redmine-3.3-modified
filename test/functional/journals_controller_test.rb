# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class JournalsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :members, :member_roles, :roles, :issues, :journals, :journal_details, :enabled_modules,
    :trackers, :issue_statuses, :enumerations, :custom_fields, :custom_values, :custom_fields_projects, :projects_trackers

  def setup
    User.current = nil
  end

  def test_index
    get :index, :project_id => 1
    assert_response :success
    assert_not_nil assigns(:journals)
    assert_equal 'application/atom+xml', @response.content_type
  end

  def test_index_with_invalid_query_id
    get :index, :project_id => 1, :query_id => 999
    assert_response 404
  end

  def test_index_should_return_privates_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true, :user_id => 1)
    @request.session[:user_id] = 2

    get :index, :project_id => 1
    assert_response :success
    assert_include journal, assigns(:journals)

    Role.find(1).remove_permission! :view_private_notes
    get :index, :project_id => 1
    assert_response :success
    assert_not_include journal, assigns(:journals)
  end

  def test_index_should_show_visible_custom_fields_only
    Issue.destroy_all
    field_attributes = {:field_format => 'string', :is_for_all => true, :is_filter => true, :trackers => Tracker.all}
    @fields = []
    @fields << (@field1 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 1', :visible => true)))
    @fields << (@field2 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 2', :visible => false, :role_ids => [1, 2])))
    @fields << (@field3 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 3', :visible => false, :role_ids => [1, 3])))
    @issue = Issue.generate!(
      :author_id => 1,
      :project_id => 1,
      :tracker_id => 1,
      :custom_field_values => {@field1.id => 'Value0', @field2.id => 'Value1', @field3.id => 'Value2'}
    )
    @issue.init_journal(User.find(1))
    @issue.update_attribute :custom_field_values, {@field1.id => 'NewValue0', @field2.id => 'NewValue1', @field3.id => 'NewValue2'}


    user_with_role_on_other_project = User.generate!
    User.add_to_project(user_with_role_on_other_project, Project.find(2), Role.find(3))
    users_to_test = {
      User.find(1) => [@field1, @field2, @field3],
      User.find(3) => [@field1, @field2],
      user_with_role_on_other_project => [@field1], # should see field1 only on Project 1
      User.generate! => [@field1],
      User.anonymous => [@field1]
    }

    users_to_test.each do |user, visible_fields|
      get :index, :format => 'atom', :key => user.rss_key
      @fields.each_with_index do |field, i|
        if visible_fields.include?(field)
          assert_select "content[type=html]", { :text => /NewValue#{i}/, :count => 1 }, "User #{user.id} was not able to view #{field.name} in API"
        else
          assert_select "content[type=html]", { :text => /NewValue#{i}/, :count => 0 }, "User #{user.id} was able to view #{field.name} in API"
        end
      end
    end

  end

  def test_diff_for_description_change
    get :diff, :id => 3, :detail_id => 4
    assert_response :success
    assert_template 'diff'

    assert_select 'span.diff_out', :text => /removed/
    assert_select 'span.diff_in', :text => /added/
  end

  def test_diff_for_custom_field
    field = IssueCustomField.create!(:name => "Long field", :field_format => 'text')
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Notes', :user_id => 1)
    detail = JournalDetail.create!(:journal => journal, :property => 'cf', :prop_key => field.id,
      :old_value => 'Foo', :value => 'Bar')

    get :diff, :id => journal.id, :detail_id => detail.id
    assert_response :success
    assert_template 'diff'

    assert_select 'span.diff_out', :text => /Foo/
    assert_select 'span.diff_in', :text => /Bar/
  end

  def test_diff_for_custom_field_should_be_denied_if_custom_field_is_not_visible
    field = IssueCustomField.create!(:name => "Long field", :field_format => 'text', :visible => false, :role_ids => [1])
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Notes', :user_id => 1)
    detail = JournalDetail.create!(:journal => journal, :property => 'cf', :prop_key => field.id,
      :old_value => 'Foo', :value => 'Bar')

    get :diff, :id => journal.id, :detail_id => detail.id
    assert_response 302
  end

  def test_diff_should_default_to_description_diff
    get :diff, :id => 3
    assert_response :success
    assert_template 'diff'

    assert_select 'span.diff_out', :text => /removed/
    assert_select 'span.diff_in', :text => /added/
  end

  def test_reply_to_issue
    @request.session[:user_id] = 2
    xhr :get, :new, :id => 6
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> This is an issue', response.body
  end

  def test_reply_to_issue_without_permission
    @request.session[:user_id] = 7
    xhr :get, :new, :id => 6
    assert_response 403
  end

  def test_reply_to_note
    @request.session[:user_id] = 2
    xhr :get, :new, :id => 6, :journal_id => 4
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> A comment with a private version', response.body
  end

  def test_reply_to_private_note_should_fail_without_permission
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true)
    @request.session[:user_id] = 2

    xhr :get, :new, :id => 2, :journal_id => journal.id
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type
    assert_include '> Privates notes', response.body

    Role.find(1).remove_permission! :view_private_notes
    xhr :get, :new, :id => 2, :journal_id => journal.id
    assert_response 404
  end

  def test_edit_xhr
    @request.session[:user_id] = 1
    xhr :get, :edit, :id => 2
    assert_response :success
    assert_template 'edit'
    assert_equal 'text/javascript', response.content_type
    assert_include 'textarea', response.body
  end

  def test_edit_private_note_should_fail_without_permission
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true)
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :edit_issue_notes

    xhr :get, :edit, :id => journal.id
    assert_response :success
    assert_template 'edit'
    assert_equal 'text/javascript', response.content_type
    assert_include 'textarea', response.body

    Role.find(1).remove_permission! :view_private_notes
    xhr :get, :edit, :id => journal.id
    assert_response 404
  end

  def test_update_xhr
    @request.session[:user_id] = 1
    xhr :post, :update, :id => 2, :notes => 'Updated notes'
    assert_response :success
    assert_template 'update'
    assert_equal 'text/javascript', response.content_type
    assert_equal 'Updated notes', Journal.find(2).notes
    assert_include 'journal-2-notes', response.body
  end

  def test_update_xhr_with_empty_notes_should_delete_the_journal
    @request.session[:user_id] = 1
    assert_difference 'Journal.count', -1 do
      xhr :post, :update, :id => 2, :notes => ''
      assert_response :success
      assert_template 'update'
      assert_equal 'text/javascript', response.content_type
    end
    assert_nil Journal.find_by_id(2)
    assert_include 'change-2', response.body
  end
end
