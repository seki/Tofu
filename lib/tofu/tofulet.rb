require 'tofu/tofu'
require 'webrick'
require 'webrick/cgi'

module WEBrick
  class TofuletContext
    include Tofu::ContextMixin

    def initialize(req, res)
      @req = req
      @res = res
    end

    def webrick_req; @req; end
    def webrick_res; @res; end

    def service(bartender)
      bartender.service(self)
      nil
    end

    # req/res interface
    # params
    def req_params
      hash = {}
      @req.query.each do |k,v|
	hash[k] = v.list
      end
      hash
    end

    # cookie
    def req_cookie(name)
      found = @req.cookies.find {|c| c.name == name}
      found ? found.value : nil
    end

    def req_cookies
      hash = {}
      @req.cookies.each do |c|
	hash[c.name] = c.value
      end
      hash
    end

    def res_add_cookie(name, value, expires=nil)
      c = WEBrick::Cookie.new(name, value)
      c.expires = expires if expires
      @res.cookies.push(c)
    end
    
    # method
    def req_method
      @req.request_method
    end
    
    def res_method_not_allowed
      raise HTTPStatus::MethodNotAllowed, "unsupported method `#{req_method}'."
    end
    
    # meta
    def req_path_info
      @req.path_info
    end

    def req_script_name
      @req.script_name
    end
    
    def req_query_string
      @req.query_string
    end
    
    def req_meta_vars
      @req.meta_vars
    end
    
    def req_https?
      @req.reuast_uri.scheme == 'https'
    end

    def req_absolute_path
      (@req.request_uri + '/').to_s.chomp('/')
    end

    # reply
    def res_body(v)
      @res.body = v
    end

    def res_header(k, v)
      if k.downcase == 'status'
	@res.status = v.to_i
	return
      end
      @res[k] = v
    end
  end

  class Tofulet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(config, bartender, *options)
      @bartender = bartender
      super(config, *options)
      @logger.debug("#{self.class}(initialize)")
    end
    attr_reader :logger, :config, :options, :bartender

    def service(req, res)
      TofuletContext.new(req, res).service(@bartender)
    end
  end

  class CGITofulet < WEBrick::CGI
    def initialize(bartender, *args)
      @bartender = bartender
      super(*args)
    end
    
    def service(req, res)
      TofuletContext.new(req, res).service(@bartender)
    end
  end
end
