require 'erb'
require 'drb/drb'
require 'monitor'
require 'digest/md5'
require 'webrick'
require 'webrick/cgi'

module Tofu
  class Session
    include MonitorMixin

    def initialize(bartender, hint=nil)
      super()
      @session_id = Digest::MD5.hexdigest(Time.now.to_s + __id__.to_s)
      @contents = {}
      @hint = hint
    end
    attr_reader :session_id
    attr_accessor :hint

    def service(context)
      case context.req_method
      when 'GET', 'POST', 'HEAD'
	do_GET(context)
      else
	context.res_method_not_allowed
      end
    end

    def expires
      Time.now + 24 * 60 * 60
    end

    def hint_expires
      Time.now + 60 * 24 * 60 * 60
    end

    def expired?
      it = expires
      it && Time.now > it
    end

    def do_GET(context)
      # update_div(context)
    end

    def update_div(context)
      params = context.req_params
      div_id ,= params['div_id']
      div = fetch(div_id)
      return unless div
      div.send_request(context, context.req_params)
    end

    def entry(div)
      synchronize do
	@contents[div.div_id] = div
      end
    end
    
    def fetch(ref)
      @contents[ref]
    end
  end

  class SessionBar
    include MonitorMixin

    def initialize
      super()
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

  class ERBMethod
    def initialize(method_name, fname, dir=nil)
      @fname = build_fname(fname, dir)
      @method_name = method_name
    end

    def reload(mod)
      erb = File.open(@fname) {|f| ERB.new(f.read)}
      erb.def_method(mod, @method_name, @fname)
    end
    
    private
    def build_fname(fname, dir)
      case dir
      when String
	ary = [dir]
      when Array
	ary = dir
      else
	ary = $:
      end

      found = fname # default
      ary.each do |dir|
	path = File::join(dir, fname)
	if File::readable?(path)
	  found = path
	  break
	end
      end
      found
    end
  end

  class Div
    include DRbUndumped
    include ERB::Util

    @erb_method = []
    def self.add_erb(method_name, fname, dir=nil)
      erb = ERBMethod.new(method_name, fname, dir)
      @erb_method.push(erb)
    end

    def self.set_erb(fname, dir=nil)
      @erb_method = [ERBMethod.new('to_html(context=nil)', fname, dir)]
      reload_erb
    end

    def self.reload_erb1(erb)
      erb.reload(self)
    rescue SyntaxError
    end

    def self.reload_erb
      @erb_method.each do |erb|
        reload_erb1(erb)
      end
    end

    def initialize(session)
      @session = session
      @session.entry(self)
      @div_seq = nil
    end
    attr_reader :session

    def div_class
      self.class.to_s
    end

    def div_id
      self.__id__.to_s
    end

    def to_div(context)
      elem('div', {'class'=>div_class, 'id'=>div_id}) {
	begin
	  to_html(context)
	rescue
	  "<p>error! #{h($!)}</p>"
	end
      }
    end

    def to_html(context)
      ''
    end

    def send_request(context, params)
      cmd, = params['div_cmd']
      msg = 'do_' + cmd.to_s

      if @div_seq
	seq, = params['div_seq']
	unless @div_seq.to_s == seq
	  p [seq, @div_seq.to_s] if $DEBUG
	  return
	end
      end

      if respond_to?(msg)
	send(msg, context, params)
      else
	do_else(context, params)
      end
    ensure
      @div_seq = @div_seq.succ if @div_seq
    end

    def do_else(context, params)
    end

    def action(context)
      context.req_script_name.to_s + context.req_path_info.to_s
    end

    private
    def attr(opt)
      ary = opt.collect do |k, v|
	if v 
	  %Q!#{k}="#{h(v)}"!
	else
	  nil
	end
      end.compact
      return nil if ary.size == 0 
      ary.join(' ')
    end

    def elem(name, opt={})
      head = ["#{name}", attr(opt)].compact.join(" ")
      if block_given?
        %Q!<#{head}>\n#{yield}\n</#{name}>!
      else
	%Q!<#{head} />!
      end  
    end

    def make_param(method_name, add_param={})
      param = {
	'div_id' => div_id,
	'div_cmd' => method_name
      }
      param['div_seq'] = @div_seq if @div_seq
      param.update(add_param)
      return param
    end

    def form(method_name, context_or_param, context_or_empty=nil)
      if context_or_empty.nil? 
	context = context_or_param
	add_param = {}
      else
	context = context_or_empty
	add_param = context_or_param
      end
      param = make_param(method_name, add_param)
      hidden = input_hidden(param)
      %Q!<form action="#{action(context)}" method="post">\n! + hidden
    end

    def href(method_name, add_param, context)
      param = make_param(method_name, add_param)
      ary = param.collect do |k, v|
	"#{u(k)}=#{u(v)}"
      end
      %Q!href="#{action(context)}?#{ary.join(';')}"!
    end

    def input_hidden(param)
      ary = param.collect do |k, v|
	%Q!<input type="hidden" name="#{h(k)}" value="#{h(v)}" />\n!
      end
      ary.join('')
    end

    def make_anchor(method, param, context)
      "<a #{href(method, param, context)}>"
    end

    def a(method, param, context)
      make_anchor(method, param, context)
    end
  end

  def reload_erb
    ObjectSpace.each_object(Class) do |o|
      if o.ancestors.include?(Div)
	o.reload_erb
      end
    end
  end
  module_function :reload_erb

  module KCode
    attr_reader(:lang, :charset)

    def kconv(s)
      return s unless @nkf
      return '' unless s
      NKF.nkf(@nkf, s)
    end

    def kconv_param(param)
      hash = {}
      param.each do |k, v|
	hash[k] = v.collect do |s|
	  kconv(s)
	end
      end
      hash
    end

    def kcode
      case $KCODE
      when /^[Ee]/
	@lang = 'ja'
	@charset = 'euc-jp'
	@nkf = '-edXm0'
      when /^[Ss]/
	@lang = 'ja'
	@charset = 'Shift_JIS'
	@nkf = '-sdXm0'
      else
	@lang = "en"
	@charset = 'us-ascii'
	@nkf = nil
      end
      require 'nkf' if @nkf
    end

    private :kcode

    module_function :lang, :charset, :kconv, :kcode, :kconv_param
    kcode()
  end

  class Context
    def initialize(req, res)
      @req = req
      @res = res
    end
    attr_reader :req, :res

    def done
      throw(:tofu_done)
    rescue NameError
      nil
    end

    def service(bartender)
      bartender.service(self)
      nil
    end

    def req_params
      hash = {}
      @req.query.each do |k,v|
	hash[k] = v.list
      end
      hash
    end

    def req_cookie(name)
      found = @req.cookies.find {|c| c.name == name}
      found ? found.value : nil
    end

    def res_add_cookie(name, value, expires=nil)
      c = WEBrick::Cookie.new(name, value)
      c.expires = expires if expires
      @res.cookies.push(c)
    end
    
    def req_method
      @req.request_method
    end
    
    def res_method_not_allowed
      raise HTTPStatus::MethodNotAllowed, "unsupported method `#{req_method}'."
    end
    
    def req_path_info
      @req.path_info
    end

    def req_script_name
      @req.script_name
    end
    
    def req_absolute_path
      (@req.request_uri + '/').to_s.chomp('/')
    end

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
      Context.new(req, res).service(@bartender)
    end
  end

  class CGITofulet < WEBrick::CGI
    def initialize(bartender, *args)
      @bartender = bartender
      super(*args)
    end
    
    def service(req, res)
      Context.new(req, res).service(@bartender)
    end
  end
end

if __FILE__ == $0
  require 'pp'

  class EnterDiv < Tofu::Div
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<%=form('enter', {}, context)%>
<dl>
<dt>hint</dt><dd><%=h @session.hint %><input class='enter' type='text' size='40' name='hint' value='<%=h @session.hint %>'/></dd>
<dt>volatile</dt><dd><%=h @session.text %><input class='enter' type='text' size='40' name='text' value='<%=h @session.text%>'/></dd>
</dl>
</form>
EOS
    def do_enter(context, params)
      hint ,= params['hint']
      @session.hint = hint || ''
      text ,= params['text']
      @session.text = text || ''
    end
  end

  class BaseDiv < Tofu::Div
    ERB.new(<<EOS).def_method(self, 'to_html(context)')
<html><title>base</title><body>
Hello, World.
<%= @enter.to_html(context) %>
<hr />
<pre><%=h context.pretty_inspect%></pre>
</body></html>
EOS
    def initialize(session)
      super(session)
      @enter = EnterDiv.new(session)
    end
  end

  class HelloSession < Tofu::Session
    def initialize(bartender, hint=nil)
      super
      @base = BaseDiv.new(self)
      @text = ''
    end
    attr_accessor :text

    def do_GET(context)
      update_div(context)

      context.res_header('content-type', 'text/html; charset=euc-jp')
      context.res_body(@base.to_html(context))
    end
  end

  tofu = Tofu::Bartender.new(HelloSession)
  DRb.start_service('druby://localhost:54322', Tofu::CGITofulet.new(tofu))
  DRb.thread.join
end
