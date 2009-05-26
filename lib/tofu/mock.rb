require 'tofu/tofu'

module Tofu
  class MockContext
    include Tofu::ContextMixin

    def initialize(context=nil)
      if context
	@req_params = context.req_params
	@req_cookies = context.req_cookies
	@req_method = context.req_method
	@req_path_info = context.req_path_info
	@req_script_name = context.req_script_name
	@req_query_string = context.req_query_string
	@req_meta_vars = context.req_meta_vars
	@req_https = context.req_https?
      else
	@req_params = nil
	@req_cookies = nil
	@req_method = nil
	@req_path_info = nil
	@req_script_name = nil
	@req_query_string = nil
	@req_meta_vars = nil
	@req_https = nil
      end
      @res_body = ''
      @res_header = {}
    end
    attr_accessor :req_params, :req_cookies, :req_method, :req_path_info
    attr_accessor :req_script_name, :req_query_string, :req_meta_vars
    attr_accessor :res_body
    attr_reader :res_header
    
    def req_https?
      @req_https
    end

    def req_cookie(name)
      @req_cookies[name]
    end
    
    def res_header(k, v)
      @res_header[k] = v
    end
  end
end
