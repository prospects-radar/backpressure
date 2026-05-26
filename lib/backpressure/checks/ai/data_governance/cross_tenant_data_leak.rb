# frozen_string_literal: true

module Backpressure
  module Checks
    module AI
      module DataGovernance
        class CrossTenantDataLeak < Check
          category "AI/DataGovernance"
          severity :error
          files "app/ai/**/*.rb"
          requires :source
          description "Flags DB queries in AI code without tenant scoping"

          QUERY_PATTERN = /\.where\b|\.find\b|\.find_by\b|\.all\b/
          TENANT_PATTERN = /acts_as_tenant|current_account|Current\.account/

          def check(context)
            return unless context.source.match?(QUERY_PATTERN)
            return if context.source.match?(TENANT_PATTERN)

            context.lines.each_with_index do |line, idx|
              next unless line.match?(QUERY_PATTERN)

              node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
              violation(node, "Database query in agent without tenant scoping — potential cross-tenant data leak")
            end
          end
        end
      end
    end
  end
end
