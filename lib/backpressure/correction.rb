# frozen_string_literal: true

module Backpressure
  class Correction
    attr_reader :line

    def apply(source)
      raise NotImplementedError
    end
  end
end
