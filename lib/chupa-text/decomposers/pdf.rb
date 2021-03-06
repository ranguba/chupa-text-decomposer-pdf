# Copyright (C) 2013-2019  Kouhei Sutou <kou@clear-code.com>
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

require "tempfile"
require "time"

require "poppler"

module ChupaText
  module Decomposers
    class PDF < Decomposer
      include Loggable

      registry.register("pdf", self)

      def target?(data)
        return true if data.mime_type == "application/pdf"

        case data.extension
        when nil, "pdf"
          (data.peek_body(6) || "").start_with?("%PDF-1")
        else
          false
        end
      end

      def decompose(data)
        document = create_document(data)
        return if document.nil?

        text = ""
        document.each do |page|
          page_text = page.get_text
          next if page_text.empty?
          text << page_text
          text << "\n" unless page_text.end_with?("\n")
        end
        text_data = TextData.new(text, :source_data => data)
        add_attribute(text_data, document, :title)
        add_attribute(text_data, document, :author)
        add_attribute(text_data, document, :subject)
        add_attribute(text_data, document, :keywords)
        add_attribute(text_data, document, :creator)
        add_attribute(text_data, document, :producer)
        add_attribute(text_data, document, :creation_date, :created_time)
        if data.need_screenshot?
          text_data.screenshot = create_screenshot(data, document)
        end
        yield(text_data)
      end

      private
      def create_document(data)
        _password = password(data)
        path = data.path
        path = path.to_path if path.respond_to?(:to_path)
        begin
          wrap_stderr do
            Poppler::Document.new(path: path, password: _password)
          end
        rescue Poppler::Error::Encrypted
          raise ChupaText::EncryptedError.new(data)
        rescue Poppler::Error => poppler_error
          error do
            message = "#{log_tag} Failed to process PDF: "
            message << "#{poppler_error.class}: #{poppler_error.message}\n"
            message << poppler_error.backtrace.join("\n")
            message
          end
          nil
        end
      end

      def password(data)
        password = @options[:password]
        if password.respond_to?(:call)
          password = password.call(data)
        end
        password
      end

      def wrap_stderr
        stderr = $stderr.dup
        stderr_log = Tempfile.new(["chupa-text-decomposer-pdf-stderr", ".log"])
        begin
          $stderr.reopen(stderr_log)
          yield
        ensure
          $stderr.reopen(stderr)
          if stderr_log.size > 0
            warn do
              stderr_log.rewind
              "#{log_tag} Messages from Poppler:\n#{stderr_log.read}"
            end
          end
        end
      end

      def add_attribute(text_data, document,
                        pdf_attribute_name, data_attribute_name=nil)
        value = document.send(pdf_attribute_name)
        return if value.nil?
        value = Time.at(value).utc.iso8601 if value.is_a?(Integer)
        data_attribute_name ||= pdf_attribute_name.to_s.gsub(/_/, "-")
        text_data[data_attribute_name] = value
      end

      def create_screenshot(data, document)
        screenshot_width, screenshot_height = data.expected_screenshot_size

        page = document[0]
        page_width, page_height = page.size

        surface = Cairo::ImageSurface.new(:argb32,
                                          screenshot_width,
                                          screenshot_height)
        context = Cairo::Context.new(surface)
        context.set_source_color(:white)
        context.paint
        if page_width > page_height
          ratio = screenshot_width / page_width
          context.translate(0,
                            ((screenshot_height - page_height * ratio) / 2))
          context.scale(ratio, ratio)
        else
          ratio = screenshot_height / page_height
          context.translate(((screenshot_width - page_width * ratio) / 2),
                            0)
          context.scale(ratio, ratio)
        end
        context.render_poppler_page(page)
        png = StringIO.new
        surface.write_to_png(png)

        Screenshot.new("image/png", [png.string].pack("m*"), "base64")
      end

      def log_tag
        "[decomposer][pdf]"
      end
    end
  end
end
