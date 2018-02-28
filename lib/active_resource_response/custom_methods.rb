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
  module CustomMethods

    extend ActiveSupport::Concern

    included do
      class << self

        alias :origin_get :get

        def get(custom_method_name, options = {})
          result = self.origin_get(custom_method_name, options)

          if self.respond_to? :http_response_method
            result = self.wrap_result(result)
          end
          
          result
        end
      end
    end

    def get(custom_method_name, options = {})
      result = super(custom_method_name, options)
      if self.class.respond_to? :http_response_method
        result = self.class.wrap_result(result)
      end
      result
    end
  end
end  
    