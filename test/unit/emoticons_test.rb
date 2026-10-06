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
require "wiki_extensions_emoticons"

class EmoticonsTest < ActiveSupport::TestCase
  fixtures :wiki_extensions_comments

  context "emoticons" do
    setup do
      @emoticons = WikiExtensionsEmoticons::Emoticons.new
    end

    should "not returns nil." do
      assert_not_nil(@emoticons.emoticons)
    end
  end
  # GEOxyz 46ffc27 (route and url_helpers at render time) and e0b64b3
  # (CommonMark); the Textile rule sits on Textile::Filter since Redmine 7.
  context "rendering" do
    should "replace emoticons with Textile" do
      html = Redmine::WikiFormatting.to_html("textile", "Smile :) here")
      assert_include '<img src="/wiki_extentions/emoticon/smile.png" alt=":)">', html
    end

    should "replace emoticons with CommonMark" do
      html = Redmine::WikiFormatting.to_html("common_mark", "Smile :) and :( here")
      assert_include '<img src="/wiki_extentions/emoticon/smile.png" alt=":)">', html
      assert_include '<img src="/wiki_extentions/emoticon/sad.png" alt=":(">', html
    end

    should "keep multibyte text intact with CommonMark" do
      html = Redmine::WikiFormatting.to_html("common_mark", "Smile :) hallo \u2192 wereld, \u00e0 \u00eb")
      assert html.valid_encoding?
      assert_include "hallo \u2192 wereld, \u00e0 \u00eb", html
    end

    should "leave text without a following space alone" do
      html = Redmine::WikiFormatting.to_html("common_mark", "a:)b and :(c")
      assert_not_include "<img", html
    end
  end
end
