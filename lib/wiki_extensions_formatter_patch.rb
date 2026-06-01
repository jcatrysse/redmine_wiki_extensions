# Wiki Extensions plugin for Redmine
# Copyright (C) 2011-2017  Haruyuki Iida
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

require_dependency "redmine/wiki_formatting/textile/formatter"

module WikiExtensionsFormatterPatch
  Redmine::WikiFormatting::Textile::Formatter::RULES << :inline_smiles

  private

  def inline_smiles(text)
    emoticon_path = WikiExtentionEmoticonPath.new

    @emoticons = WikiExtensionsEmoticons::Emoticons.new
    @emoticons.emoticons.each { |emoticon|
      src = emoticon_path.get_emoticon_path(emoticon["image"])
      text.gsub!(Regexp.new("#{Regexp.escape(emoticon["emoticon"])}(\\s|<br/>|</p>)"),
                 "<img src=\"#{src}\" alt=\"#{emoticon["emoticon"]}\">\\1")
    }
  end

  class WikiExtentionEmoticonPath
    def get_emoticon_path(emoticon)
      Rails.application.routes.url_helpers.wiki_extensions_emoticon_path(emoticon)
    end
  end
end

Redmine::WikiFormatting::Textile::Formatter.prepend(WikiExtensionsFormatterPatch)

begin
  require_dependency "redmine/wiki_formatting/common_mark/formatter"

  module WikiExtensionsCommonMarkFormatterPatch
    def to_html(*rules)
      html = super

      # Preserve the original encoding and ensure we operate in UTF-8.
      # CommonMark may return ASCII-8BIT; gsub on a binary string that
      # contains multi-byte UTF-8 sequences (e.g. → U+2192) would
      # corrupt those sequences if the replacement string re-encodes them.
      original_encoding = html.encoding
      html = html.encode('UTF-8') unless html.encoding == Encoding::UTF_8

      emoticon_path = WikiExtensionsFormatterPatch::WikiExtentionEmoticonPath.new
      WikiExtensionsEmoticons::Emoticons.new.emoticons.each do |emoticon|
        src = emoticon_path.get_emoticon_path(emoticon["image"])
        html = html.gsub(
          Regexp.new("#{Regexp.escape(emoticon["emoticon"])}(\\s|<br\\s*/?>|</p>)"),
          "<img src=\"#{src}\" alt=\"#{emoticon["emoticon"]}\">\\1"
        )
      end

      html.encoding == original_encoding ? html : html.encode(original_encoding)
    end
  end

  Redmine::WikiFormatting::CommonMark::Formatter.prepend(WikiExtensionsCommonMarkFormatterPatch)
rescue LoadError
  # CommonMark formatter not available in this Redmine installation
end
