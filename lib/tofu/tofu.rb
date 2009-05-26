require 'monitor'
require 'digest/md5'

module Tofu
  class Session
    def initialize(bartender, hint=nil) 
      @session_id = Digest::MD5.hexdigest(Time.now.to_s + __id__.to_s)
    end
    attr_reader :session_id
    def service(context); end
    def hint; nil; end
    def expires
      Time.now + 24 * 60 * 60
    end
    def expired?
      it = expires
      it && Time.now > it
    end
  end

  class SessionBar
    include MonitorMixin
    def initialize
      super
      @pool = {}
      @keeper = keeper
      @interval = 60
    end

    def store(session)
      key = session.session_id
      synchronize do
        @pool[key] = session
      end
      @keeper.wakeup
      return key
    end

    def fetch(key)
      return nil if key.nil?
      synchronize do
        session = @pool[key]
        return nil unless session
        if session.expired?
          @pool.delete(key)
          return nil
        end
        return session
      end
    end

    private
    def keeper
      Thread.new do
        loop do
          synchronize do
            @pool.delete_if do |k, v| 
              v.nil? || v.expired?
            end
          end
          Thread.stop if @pool.size == 0
          sleep @interval
        end
      end
    end
  end

  class Bartender
    def initialize(factory, name=nil)
      @factory = factory
      @prefix = name ? name : factory.to_s.split(':')[-1]
      @bar = SessionBar.new
    end
    attr_reader :prefix

    def service(context)
      begin
	session = retrieve_session(context)
	catch(:tofu_done) { session.service(context) }
	store_session(context, session)
      ensure
	context.close
      end
    end

    private
    def retrieve_session(context)
      sid = context.req_cookie(@prefix + '_id')
      session = @bar.fetch(sid) || make_session(context)
      return session
    end

    def store_session(context, session)
      sid = @bar.store(session)
      context.res_add_cookie(@prefix + '_id', sid, session.expires)
      hint = session.hint
      if hint
	expires = Time.now + 60 * 24 * 60 * 60
	context.res_add_cookie(@prefix +'_hint', hint, expires)
      end
      return sid
    end

    def make_session(context)
      hint = context.req_cookie(@prefix +  '_hint')
      @factory.new(self, hint)
    end
  end

  module ContextMixin
    def done
      throw(:tofu_done)
    rescue NameError
      nil
    end

    def close; end

    # req/res interface
    # params
    def req_params; raise NotImplementedError; end

    # cookie
    def req_cookie(name); raise NotImplementedError; end
    def req_cookies; raise NotImplementedError; end
    def res_add_cookie(name, value, expires=nil); raise NotImplementedError; end
    
    # method
    def req_method; raise NotImplementedError; end
    def res_method_not_allowed; raise NotImplementedError; end
    
    # meta
    def req_path_info; raise NotImplementedError; end
    def req_script_name; raise NotImplementedError; end
    def req_query_string; raise NotImplementedError; end
    def req_meta_vars; raise NotImplementedError; end
    def req_https?
      req_meta_vars['HTTPS'] == 'on'
    end
    
    def req_absolute_path
      meta = req_meta_vars
      host = meta['SERVER_NAME'] || '80'
      port = meta['SERVER_PORT'] || 'localhost'
      if req_https?
	if port == '443' 
	  "https://#{host}"
	else
	  "https://#{host}:#{port}"
	end
      else
	if port == '80' 
	  "http://#{host}"
	else
	  "http://#{host}:#{port}"
	end
      end
    end
    
    # reply
    def res_body(v); raise NotImplementedError; end
    def res_header(k, v); raise NotImplementedError; end
  end
end
