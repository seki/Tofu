require 'erb'
require 'drb'

module Div

  class DivMethod
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

    @erb_method = []

    def self.add_erb(method_name, fname, dir=nil)
      erb = DivMethod.new(method_name, fname, dir)
      @erb_method.push(erb)
    end

    def self.set_erb(fname, dir=nil)
      @erb_method = [DivMethod.new('to_html(context=nil)', fname, dir)]
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
      @action = session.action
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
    alias :to_s :to_div

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

    def action(context=nil)
      if context
	context.req_script_name.to_s + context.req_path_info.to_s
      else
	@action
      end
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

    def html_escape(s)
      s.to_s.gsub(/&/n, '&amp;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
    end
    alias h html_escape

    def url_encode(s)
      s.to_s.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
	'%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end
    alias u url_encode
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
end
