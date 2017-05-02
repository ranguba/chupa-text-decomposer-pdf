# Copyright (C) 2013-2014  Kouhei Sutou <kou@clear-code.com>
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

require "time"

require "poppler"

module ChupaText
  module Decomposers
    class PDF < Decomposer
      registry.register("pdf", self)

      def target?(data)
        (data.extension == "pdf" and data.body.start_with?("%PDF-1")) or
          data.mime_type == "application/pdf"
      end

      def decompose(data)
        document = create_document(data)
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
        yield(text_data)
      end

      private
      def create_document(data)
        _password = password(data)
        begin
          wrap_stderr do
            Poppler::Document.new(data.body, _password)
          end
        rescue GLib::Error => error
          case error.code
          when Poppler::Error::ENCRYPTED.to_i
            raise ChupaText::EncryptedError.new(data)
          else
            raise ChupaText::InvalidDataError.new(data, error.message)
          end
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
        input, output = IO.pipe
        _ = input # TODO: Report output
        $stderr.reopen(output)
        yield
      ensure
        $stderr.reopen(stderr)
      end

      def add_attribute(text_data, document,
                        pdf_attribute_name, data_attribute_name=nil)
        value = document.send(pdf_attribute_name)
        return if value.nil?
        value = Time.at(value).utc.iso8601 if value.is_a?(Integer)
        data_attribute_name ||= pdf_attribute_name.to_s.gsub(/_/, "-")
        text_data[data_attribute_name] = value
      end
    end
  end
end
