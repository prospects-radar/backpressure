# frozen_string_literal: true

module Backpressure
  class CheckRegistry
    def initialize
      @checks = []
    end

    def register(check_class)
      @checks << check_class unless @checks.include?(check_class)
    end

    def all
      @checks.dup
    end

    def for_file(path)
      @checks.select { |c| c.matches_file?(path) }
    end

    def by_name(name)
      @checks.find { |c| c.check_name == name }
    end

    def by_category(prefix)
      @checks.select { |c| c.check_category&.start_with?(prefix) }
    end

    def load_from(directory)
      Dir.glob(File.join(directory, "**", "*.rb")).sort.each do |file|
        checks_before = check_descendants
        require file
        new_checks = check_descendants - checks_before
        new_checks.reject { |c| c == Backpressure::AiCheck }.each { |c| register(c) }
      end
    end

    private

    def check_descendants
      ObjectSpace.each_object(Class).select { |c| c < Backpressure::Check }
    end
  end
end
