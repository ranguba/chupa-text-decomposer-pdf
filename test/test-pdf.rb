# Copyright (C) 2013-2017  Kouhei Sutou <kou@clear-code.com>
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
require "gdk_pixbuf2"

class TestPDF < Test::Unit::TestCase
  def setup
    @options = {}
  end

  private
  def decomposer
    ChupaText::Decomposers::PDF.new(@options)
  end

  def fixture_path(*components)
    base_path = Pathname(__FILE__).dirname + "fixture"
    base_path.join(*components)
  end

  sub_test_case("target?") do
    sub_test_case("extension") do
      def create_data(uri)
        data = ChupaText::Data.new
        data.body = "%PDF-1.4"
        data.uri = uri
        data.mime_type = "application/octet-stream"
        data
      end

      def test_pdf
        assert do
          decomposer.target?(create_data("index.pdf"))
        end
      end

      def test_html
        assert do
          not decomposer.target?(create_data("index.html"))
        end
      end
    end

    sub_test_case("mime-type") do
      def create_data(mime_type)
        data = ChupaText::Data.new
        data.mime_type = mime_type
        data
      end

      def test_pdf
        assert_true(decomposer.target?(create_data("application/pdf")))
      end

      def test_html
        assert_false(decomposer.target?(create_data("text/html")))
      end
    end
  end

  sub_test_case("decompose") do
    private
    def decompose(path)
      data = ChupaText::InputData.new(path)
      data.mime_type = "text/pdf"

      decomposed = []
      decomposer.decompose(data) do |decomposed_data|
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

      def test_created_time
        if ENV["TRAVIS"] # TODO: Why? We set TZ=JST in run-test.rb
          assert_equal([Time.parse("2014-01-05T15:52:45Z")],
                       decompose("created_time"))
        else
          assert_equal([Time.parse("2014-01-05T06:52:45Z")],
                       decompose("created_time"))
        end
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
        assert_equal(["Page1\n"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("one-page.pdf"))
      end
    end

    sub_test_case("multi pages") do
      def test_body
        assert_equal(["Page1\nPage2\n"], decompose.collect(&:body))
      end

      private
      def decompose
        super(fixture_path("multi-pages.pdf"))
      end
    end

    sub_test_case("encrypted") do
      def test_with_password
        @options = {:password => "encrypted"}
        assert_equal(["Password is 'encrypted'.\n"],
                     decompose.collect(&:body))
      end

      def test_with_password_block
        @options = {:password => lambda {|data| "encrypted"}}
        assert_equal(["Password is 'encrypted'.\n"],
                     decompose.collect(&:body))
      end

      def test_without_password
        assert_raise(ChupaText::EncryptedError) do
          decompose
        end
      end

      private
      def decompose
        super(fixture_path("encrypted.pdf"))
      end
    end

    sub_test_case("screenshot") do
      def test_with_password
        assert_equal([
                       {
                         "mime-type" => "image/png",
                         "pixels" => load_image_fixture("screenshot.png"),
                         "encoding" => "base64",
                       },
                     ],
                     decompose("screenshot.pdf"))
      end

      private
      def decompose(fixture_name)
        super(fixture_path(fixture_name)).collect do |decompose|
          screenshot = decompose.screenshot
          {
            "mime-type" => screenshot.mime_type,
            "pixels" => load_image_data(screenshot.decoded_data),
            "encoding" => screenshot.encoding,
          }
        end
      end

      def load_image_data(data)
        loader = GdkPixbuf::PixbufLoader.new
        loader.write(data)
        loader.close
        loader.pixbuf.pixels
      end

      def load_image_fixture(fixture_name)
        File.open(fixture_path(fixture_name), "rb") do |file|
          load_image_data(file.read)
        end
      end
    end
  end
end
