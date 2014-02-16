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

require "time"

require "poppler"

module ChupaText
  module Decomposers
    class PDF < Decomposer
      registry.register("pdf", self)

      def target?(data)
        data.extension == "pdf" or
          data.mime_type == "application/pdf"
      end

      def decompose(data)
        document = Poppler::Document.new(data.body)
        text = ""
        document.each do |page|
          page_text = page.get_text
          next if page_text.empty?
          text << "\n" unless text.empty?
          text << page_text
        end
        text_data = TextData.new(text)
        text_data.uri = data.uri
        add_attribute(text_data, document, :title)
        add_attribute(text_data, document, :author)
        add_attribute(text_data, document, :subject)
        add_attribute(text_data, document, :keywords)
        add_attribute(text_data, document, :creator)
        add_attribute(text_data, document, :producer)
        add_attribute(text_data, document, :creation_date)
        yield(text_data)
      end

      private
      def add_attribute(text_data, document, name)
        value = document.send(name)
        return if value.nil?
        attribute_name = name.to_s.gsub(/_/, "-")
        value = Time.at(value).utc.iso8601 if value.is_a?(Integer)
        text_data[attribute_name] = value
      end
    end
  end
end
