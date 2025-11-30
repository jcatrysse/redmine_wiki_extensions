# Wiki Extensions plugin for Redmine
# Copyright (C) 2012-2015  Haruyuki Iida
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

RedmineApp::Application.routes.draw do
  scope 'projects/:id', as: 'project' do
    match 'wiki_extensions/stylesheet', to: 'wiki_extensions#stylesheet', via: [:get, :post], as: 'wiki_extensions_stylesheet'

    get    'wiki_extensions/show_vote',     to: 'wiki_extensions#show_vote'
    post   'wiki_extensions/vote',          to: 'wiki_extensions#vote'
    post   'wiki_extensions/add_comment',   to: 'wiki_extensions#add_comment'
    post   'wiki_extensions/reply_comment', to: 'wiki_extensions#reply_comment'
    match  'wiki_extensions/destroy_comment', to: 'wiki_extensions#destroy_comment', via: [:get, :delete]
    match  'wiki_extensions/update_comment',  to: 'wiki_extensions#update_comment',  via: [:post, :patch]
    get    'wiki_extensions/forward_wiki_page', to: 'wiki_extensions#forward_wiki_page'
    get    'wiki_extensions/show_comments',     to: 'wiki_extensions#show_comments'
    get    'wiki_extensions/tag',               to: 'wiki_extensions#tag'

    get    'wiki_extensions_settings', to: 'wiki_extensions_settings#show',   as: 'wiki_extensions_settings'
    match  'wiki_extensions_settings', to: 'wiki_extensions_settings#update', via: [:post, :put, :patch]
  end
end
