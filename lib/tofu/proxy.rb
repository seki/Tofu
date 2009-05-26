require 'drb/drb'
require 'tofu/tofu'
require 'forwardable'

module Tofu
  class ContextProxy
    include ContextMixin
    extend Forwardable

    def_delegators(:@remote,
		   :res_add_cookie, :res_method_not_allowed,
                   :res_method_not_allowed,
		   :res_body, :res_header, :close)
		   
    def initialize(context)
      @remote = DRbObject.new(context)
      @req_params = context.req_params
      @req_cookies = context.req_cookies
      @req_method = context.req_method
      @req_path_info = context.req_path_info
      @req_script_name = context.req_script_name
      @req_query_string = context.req_query_string
      @req_meta_vars = context.req_meta_vars
    end
    attr_reader :req_params, :req_cookies, :req_method, :req_path_info
    attr_reader :req_script_name, :req_query_string, :req_meta_vars
    
    def req_cookie(name)
      cookie = @req_cookies[name]
      if Array === cookie
        cookie[0]
      else
        cookie
      end
    end
  end
end
