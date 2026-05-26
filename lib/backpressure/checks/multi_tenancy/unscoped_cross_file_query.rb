# frozen_string_literal: true

module Backpressure
  module Checks
    module MultiTenancy
      class UnscopedCrossFileQuery < Check
        category "MultiTenancy"
        severity :error
        files "app/services/**/*.rb"
        requires :source
        description "Flags DB queries without tenant scoping in multi-tenant code"

        QUERY_METHODS = /\.(where|find|find_by|all|first|last|count|pluck)\b/
        TENANT_SAFE = /acts_as_tenant|Current\.account|current_account|ActsAsTenant/

        def check(context)
          return if context.source.match?(TENANT_SAFE)

          context.lines.each_with_index do |line, idx|
            next unless line.match?(QUERY_METHODS)

            node = OpenStruct.new(loc: OpenStruct.new(line: idx + 1, column: 0))
            violation(node, "Database query in service without tenant scoping — verify model uses `acts_as_tenant`")
          end
        end
      end
    end
  end
end
