# Copyright (C) 2013  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "pathname"

class TestPDF < Test::Unit::TestCase
  def setup
    @decomposer = ChupaText::Decomposers::PDF.new({})
  end

  private
  def fixture_path(*components)
    base_path = Pathname(__FILE__).dirname + "fixture"
    base_path.join(*components)
  end

  sub_test_case("target?") do
    sub_test_case("extension") do
      def create_data(uri)
        data = ChupaText::Data.new
        data.body = ""
        data.uri = uri
        data
      end

      def test_pdf
        assert_true(@decomposer.target?(create_data("index.pdf")))
      end

      def test_html
        assert_false(@decomposer.target?(create_data("index.html")))
      end
    end

    sub_test_case("mime-type") do
      def create_data(mime_type)
        data = ChupaText::Data.new
        data.mime_type = mime_type
        data
      end

      def test_pdf
        assert_true(@decomposer.target?(create_data("application/pdf")))
      end

      def test_html
        assert_false(@decomposer.target?(create_data("text/html")))
      end
    end
  end

  sub_test_case("decompose") do
    private
    def decompose(path)
      data = ChupaText::InputData.new(path)
      data.mime_type = "text/pdf"

      decomposed = []
      @decomposer.decompose(data) do |decomposed_data|
        decomposed << decomposed_data
      end
      decomposed
    end

    sub_test_case("attributes") do
      def test_title
        assert_equal(["Title"], decompose("title"))
      end

      def test_author
        assert_equal([nil], decompose("author"))
      end

      def test_subject
        assert_equal(["Subject"], decompose("subject"))
      end

      def test_keywords
        assert_equal(["Keyword1, Keyword2"], decompose("keywords"))
      end

      def test_creator
        assert_equal(["Writer"], decompose("creator"))
      end

      def test_producer
        assert_equal(["LibreOffice 4.1"], decompose("producer"))
      end

      def test_creation_date
        assert_equal([nil], decompose("creation_date"))
      end

      private
      def decompose(attribute_name)
        super(fixture_path("attributes.pdf")).collect do |data|
          data[attribute_name]
        end
      end
    end

    sub_test_case("one page") do
      def test_body
        assert_equal(["Page1"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("one-page.pdf"))
      end
    end

    sub_test_case("multi pages") do
      def test_body
        assert_equal(["Page1\nPage2"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("multi-pages.pdf"))
      end
    end
  end
end
