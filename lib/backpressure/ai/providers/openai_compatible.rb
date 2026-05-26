# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Backpressure
  module AI
    module Providers
      class OpenAiCompatible < Provider
        def complete(prompt:, model:, temperature:, max_tokens:, schema:)
          uri = URI.join(base_url.chomp("/") + "/", "chat/completions")
          body = build_request_body(prompt, model, temperature, max_tokens, schema)

          response = post(uri, body)
          parse_response(response)
        end

        private

        def base_url
          provider_config["url"] || raise(Backpressure::Error, "openai_compatible: 'url' is required in ai config")
        end

        def api_key
          key = provider_config["api_key"]
          return nil unless key

          key.start_with?("${") ? ENV.fetch(key[2..-2], nil) : key
        end

        def provider_config
          config["openai_compatible"] || {}
        end

        def build_request_body(prompt, model, temperature, max_tokens, schema)
          body = {
            model: model || provider_config["model"] || "gpt-4o-mini",
            messages: [
              { role: "system", content: "You are a code analysis tool. Respond only with valid JSON matching the requested schema." },
              { role: "user", content: prompt }
            ],
            temperature: temperature || 0,
            max_tokens: max_tokens || 1024
          }

          if schema
            body[:response_format] = {
              type: "json_schema",
              json_schema: {
                name: "violations",
                strict: true,
                schema: deep_stringify(schema)
              }
            }
          end

          body
        end

        def post(uri, body)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = 60

          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{api_key}" if api_key

          request.body = JSON.generate(body)
          http.request(request)
        end

        def parse_response(response)
          unless response.is_a?(Net::HTTPSuccess)
            raise Backpressure::Error, "OpenAI-compatible API error (#{response.code}): #{response.body}"
          end

          data = JSON.parse(response.body)
          content = data.dig("choices", 0, "message", "content")
          raise Backpressure::Error, "No content in API response" unless content

          parsed = JSON.parse(content)
          parsed.is_a?(Array) ? parsed : Array(parsed["items"] || parsed["violations"] || [parsed])
        rescue JSON::ParserError => e
          raise Backpressure::Error, "Failed to parse API response: #{e.message}"
        end

        def deep_stringify(obj)
          case obj
          when Hash then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
          when Array then obj.map { |v| deep_stringify(v) }
          else obj
          end
        end
      end
    end
  end
end

Backpressure::AI::Provider.register(:openai_compatible, Backpressure::AI::Providers::OpenAiCompatible)
