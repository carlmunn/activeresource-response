#--
# Copyright (c) 2012 Igor Fedoronchuk
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++
module ActiveResourceResponse
  module Connection
    def self.included(base)

      base.class_eval do
        
        alias_method :origin_handle_response, :handle_response
        alias_method :request_without_caching, :request

        # Overwritten to enable caching specific URL using an regexp
        def request(meth, path, *args)

          if cache_option = _cache?(meth, path)
            
            _cache_key = _gen_key(path, namespace: cache_option[:namespace])

            _log("CACHE: Request found using #{cache_option[:regex]}. Using key '#{_cache_key}'")

            result = Rails.cache.fetch(_cache_key, expires_in: cache_option[:expires_in]) do
              _log("CACHE: Populating cache! (expires_in: #{cache_option[:expires_in]})")
              request_without_caching(meth, path, *args)
            end
          else
            _log("CACHE: No match found for path '#{path}'")
            result = request_without_caching(meth, path, *args)
          end

          result

          rescue => exp
            _exception_warn(exp)
            raise exp unless Rails.env.production?
            request_without_caching(meth, path, *args)
        end

        def handle_response(response)
          begin
            origin_handle_response(response)
          rescue
            raise
          ensure
            response.extend HttpResponse
            self.http_response=(response)
          end
        end

        def http_response
          http_storage[:ActiveResourceResponse]
        end

        def http_response=(response)
          http_storage[:ActiveResourceResponse] = response
        end
        
        def http_storage
          Thread.current
        end

        private
          def _cache?(meth, path)

            return false if cache_settings.blank?

            _log "Checking for match"

            if meth == :get && (_cache = _select_cache_options(path))
              _cache
            end
          end

          def _log(msg)
            Rails.logger.debug("[D][ActiveResourceResponse] #{msg}")
          end

          # Split the URI from the params, the URI is more human friendly to read
          # while params are hashed and truncated
          # Example: activeresource
          # +namespace+ to be more specific, like country codes
          def _gen_key(path, namespace: nil)
            _uri, _params = _split_path(path)
            _uri_modified = _uri.gsub(/\//, "_").gsub(/\./, "-")
            _param_hash   = _params && Digest::SHA256.hexdigest(_params)[0..6]

            namespace = namespace.call if namespace.is_a?(Proc)

            ['activeresource', namespace, _uri_modified, _param_hash].reject(&:blank?).join('-')
          end

          # Regex the path, ignore the query
          def _select_cache_options(path)
            cache_settings.select do |hsh|
              hsh[:regex] === _split_path(path).first
            end.first
          end

          def _split_path(path)
            [*path.split("?"), nil][0...3]
          end

          def _exception_warn(exp)
            Rails.logger.warn("EXCEPTION! ActiveResourceResponse caching; defaulting to normal behaviour (#{exp.message})")
          end

          def cache_settings
            ActiveResourceResponse.http_response_caching
          end
      end
    end
  end
end
