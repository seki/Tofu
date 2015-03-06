require 'tofu'
require 'rinda/tuplespace'
require 'singleton'
require 'digest/md5'
require 'enumerator'

class Njet
  def initialize(value)
    @value = value
  end
  
  def ===(other)
    @value != other
  end
end

class Store
  include Singleton

  def initialize
    @tree = []
    @ts = Rinda::TupleSpace.new(3)
    @ts.write([:latest, 0])
  end
  attr_reader :tree

  def each_slice(n, &blk)
    _, key = @ts.take([:latest, nil])
    @tree.each_slice(n, &blk)
    nil
  ensure
    @ts.write([:latest, key])
  end

  def headline
    _, value = @tree.first
    value ? value[0] : nil
  end

  def via_drb
    'drb ' + Thread.current[:DRb]['client'].stream.peeraddr[2] rescue nil
  end

  def via_cgi(context)
    context.req.peeraddr[2] rescue nil
  end
  
  def latest
    @ts.read([:latest, nil])[1]
  end
  
  def wait(key)
    @ts.read([:latest, Njet.new(key)], 10) rescue nil
  end
  
  def import_string(str)
    str.dup.force_encoding('utf-8')
  rescue
    "(?)"
  end

  def add(str, context=nil)
    str = import_string(str)
    from = context ? via_cgi(context) : via_drb
    from ||= 'local'
    @ts.take([:latest, nil])
    begin
      key = -10 * Time.now.to_f
      @tree.unshift([key, [str, from]])
      str
    ensure
      @ts.write([:latest, key.to_i])
    end
  end
end

class KotoSession < Tofu::Session
  def initialize(bartender, hint=nil)
    super
    @content = Store.instance
    @base = BaseTofu.new(self)
    @age = nil
    @interval = 5000
  end
  attr_reader :interval
  attr_reader :content

  def expires
    Time.now + 60
  end

  def do_GET(context)
    dispatch_tofu(context)
    
    context.res_header('pragma', 'no-cache')
    context.res_header('cache-control', 'no-cache')
    context.res_header('expires', 'Thu, 01 Dec 1994 16:00:00 GMT')
    return if do_inner_html(context)
    reset_age
    context.res_header('content-type', 'text/html; charset=utf-8')
    context.res_body(@base.to_html(context))
  end

  def wait
    @content.wait(@age) if @age
    @age = @content.latest
  end

  def reset_age
    @age = nil
  end

  def headline
    @content.headline || 'Koya'
  end
end

class BaseTofu < Tofu::Tofu
  set_erb('base.erb')
  
  def initialize(session)
    super(session)
    @enter = EnterTofu.new(session)
    @list = ListTofu.new(session)
  end
end

class EnterTofu < Tofu::Tofu
  set_erb('enter.erb')
  
  def do_enter(context, params)
    str ,= params['str']
    str = '(nil)' if (str.nil? || str.empty?)
    @session.content.add(str, context)
    @session.reset_age
  end

  def tofu_id
    'enter'
  end
end

class ListTofu < Tofu::Tofu
  set_erb('list.erb')

  Color = Hash.new do |h, k|
    md5 = Digest::MD5.new
    md5 << k.to_s
    r = 0b01111111 & md5.digest[0].unpack("c").first
    g = 0b01111111 & md5.digest[1].unpack("c").first
    b = 0b01111111 & md5.digest[2].unpack("c").first
    h[k] = sprintf("#%02x%02x%02x", r, g, b)
  end

  def initialize(session)
    super(session)
    @content = session.content
    @color = Color
  end

  def group_header(from, time)
    from + ' @ ' + time.strftime("%H:%M")
  end
end

class MyTofulet < Tofu::CGITofulet
  def [](key)
    Store.instance if key == 'store'
  end
end

tofu = Tofu::Bartender.new(KotoSession, 'koto_8080')
s = WEBrick::HTTPServer.new(:Port => 8080)
s.mount("/", Tofu::Tofulet, tofu)
s.start

=begin
# dRuby & CGI style
unless $DEBUG
  exit!(0) if fork
  Process.setsid
  exit!(0) if fork
end

uri = ARGV.shift || 'druby://localhost:54322'
tofu = Tofu::Bartender.new(KotoSession, 'koto_' + uri.split(':').last)
DRb.start_service(uri, MyTofulet.new(tofu))

unless $DEBUG
  STDIN.reopen('/dev/null')
  STDOUT.reopen('/dev/null', 'w')
  STDERR.reopen('/dev/null', 'w')
end

DRb.thread.join
=end

