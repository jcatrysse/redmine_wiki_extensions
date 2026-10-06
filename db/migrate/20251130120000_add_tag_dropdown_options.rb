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

# GEOxyz-only migration. It was 0015_add_tag_dropdown_options until the
# Redmine 7 migration; it got a timestamp so that a future upstream 0015
# cannot collide with it. Databases that ran the old 0015 already have the
# column, and their "15-redmine_wiki_extensions" row would make Redmine skip
# an upstream 0015, so that row is removed here.
class AddTagDropdownOptions < ActiveRecord::Migration[4.2]
  LEGACY_VERSION = '15-redmine_wiki_extensions'.freeze

  def self.up
    unless column_exists?(:wiki_extensions_settings, :tag_dropdown_options)
      add_column(:wiki_extensions_settings, :tag_dropdown_options, :text)
    end
    execute("DELETE FROM #{quote_table_name(ActiveRecord::Base.schema_migrations_table_name)} " \
            "WHERE version = #{quote(LEGACY_VERSION)}")
  end

  def self.down
    remove_column(:wiki_extensions_settings, :tag_dropdown_options)
  end
end
