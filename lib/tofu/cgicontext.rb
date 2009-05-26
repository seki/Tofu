require 'tofu/tofu'
require 'cgi'

module Tofu
  class CGIContext
    include Tofu::ContextMixin

    def initialize(cgi)
      @cgi = cgi
      @params = cgi.params
      @cookies = []
      @body = ''
      @header = {}
      @res = @cgi
      @meta = meta_vars
    end

    def close
      @header['cookie'] = @cookies
      @cgi.out(@header) { @body }
    end

    def service(bartender)
      bartender.service(self)
    end
    
    # req/res interface
    # params
    def req_params
      @params
    end

    # cookie
    def req_cookie(name)
      @cgi.cookies[name][0]
    end

    def req_cookies
      hash = {}
      @cgi.cookies.each do |k, v|
	hash[k] = v[0]
      end
      hash
    end

    def res_add_cookie(name, value, expires=nil)
      c = CGI::Cookie.new(name, value)
      c.expires = expires if expires
      @cookies.push(c)
      nil
    end
    
    # method
    def req_method
      @cgi.request_method
    end
    
    def res_method_not_allowed
      # FIXME
      @body = "unsupported method `#{req_method}'."
      @header['content-type'] = 'text/plain'
      @header['status'] = "METHOD_NOT_ALLOWED"
    end
    
    # meta
    def req_path_info
      @cgi.path_info
    end

    def req_script_name
      @cgi.script_name
    end
    
    def req_query_string
      @cgi.query_string
    end
    
    def meta_vars
      meta = {}
      for env in %w[ AUTH_TYPE CONTENT_TYPE GATEWAY_INTERFACE PATH_INFO
	  PATH_TRANSLATED QUERY_STRING REMOTE_ADDR REMOTE_HOST
	  REMOTE_IDENT REMOTE_USER REQUEST_METHOD SCRIPT_NAME
	  SERVER_NAME SERVER_PROTOCOL SERVER_SOFTWARE

	  HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
	  HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM HTTP_HOST
	  HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ]
	meta[env] = @cgi.send(env.sub(/^HTTP_/n, '').downcase)
      end
      
      for env in %w[HTTP_IF_MODIFIED_SINCE HTTPS]
	meta[env] = ENV[env] if ENV.include?(env)
      end
      meta
    end

    def req_meta_vars
      @meta
    end

    # reply
    def res_body(v)
      @body = v
    end

    def res_header(k, v)
      @header[k.downcase] = v
    end
  end
end
