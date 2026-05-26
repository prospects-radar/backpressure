# frozen_string_literal: true

module Backpressure
  module Formatters
    class Base
      def format(violations)
        raise NotImplementedError
      end
    end
  end
end
