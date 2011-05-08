# encoding: UTF-8

module Nokogiri
  module XML
    class Node
      # Override equality testing so we can use MiniTest::Mock#expect with
      # Nokogiri::XML::Node arguments. Node's default behavior considers
      # all nodes unequal.
      def ==(node)
        self.to_s == node.to_s
      end
    end
  end
end