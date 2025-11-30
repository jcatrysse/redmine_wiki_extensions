# Wiki Extensions plugin for Redmine
# Copyright (C) 2009-2014  Haruyuki Iida
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

class WikiExtensionsUtil
  DEFAULT_TAG_DROPDOWN_OPTIONS = [
    'draft',
    'in-review',
    'approved',
    'archived',
    'obsolete',
    'needs-update'
  ].freeze

  def WikiExtensionsUtil.is_enabled?(project)
    return false unless project
    project.module_enabled? 'wiki_extensions'
  end

  def WikiExtensionsUtil.tag_enabled?(project)
    return false unless project
    setting = WikiExtensionsSetting.find_or_create(project.id)
    !setting.tag_disabled
  end

  def WikiExtensionsUtil.tag_dropdown_options(project)
    project_options = WikiExtensionsSetting.find_or_create(project.id).tag_dropdown_options
    global_options = Setting.plugin_redmine_wiki_extensions['tag_dropdown_options'] if Setting.respond_to?(:plugin_redmine_wiki_extensions)

    parsed_options = WikiExtensionsUtil.parse_tag_dropdown_options(project_options)
    parsed_options = WikiExtensionsUtil.parse_tag_dropdown_options(global_options) if parsed_options.empty?

    parsed_options.presence || DEFAULT_TAG_DROPDOWN_OPTIONS
  end

  def WikiExtensionsUtil.tag_dropdown_options_with_blank(project)
    [''] + WikiExtensionsUtil.tag_dropdown_options(project)
  end

  private

  def WikiExtensionsUtil.parse_tag_dropdown_options(raw_options)
    return [] unless raw_options

    raw_options.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
  end
end
