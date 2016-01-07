# -*- coding: utf-8 -*-
require 'tofu'
require 'singleton'
require 'digest/md5'
require 'enumerator'
require 'drip'

class NazoSession < Tofu::Session
  def initialize(bartender, hint=nil)
    super
    @base = BaseTofu.new(self)
  end
  attr_reader :interval
  attr_reader :content

  def do_GET(context)
    dispatch_event(context)

    context.res_header('pragma', 'no-cache')
    context.res_header('cache-control', 'no-cache')
    context.res_header('expires', 'Thu, 01 Dec 1994 16:00:00 GMT')
    context.res_header('content-type', 'text/html; charset=utf-8')
    context.res_body(@base.to_html(context))
  end

  def headline
    'nazo nazo auth'
  end
end

class BaseTofu < Tofu::Tofu
  set_erb('base.erb')
  
  def initialize(session)
    super(session)
    @prompt = PromptTofu.new(session)
  end
end

class PromptTofu < Tofu::Tofu
  set_erb('prompt.erb')

  def initialize(session)
    super(session)
    @nazo = get_nazo
  end
  
  def do_prompt(context, params)
    answer ,= params['answer']
    p answer
    it = answer.encode('utf-8')
    p it
    p @nazo[:choose][0] == it
    @nazo = get_nazo
  end

  def tofu_id
    'prompt'
  end

  def get_nazo
    [{:question => 'きずぐすりで回復するのは何ダメージ？',
      :choose => ['30', '20', '40', '10']},
     {:question => 'シェイミEXのセットアップは手札が何枚になるまで引く？',
      :choose => ['6']}].sort_by {rand}[0]
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

  def to_inner_html(context)
    @session.wait
    to_html(context)
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

# WEBrick::Daemon.start unless $DEBUG
tofu = Tofu::Bartender.new(NazoSession, 'nazo_8082')
s = WEBrick::HTTPServer.new(:Port => 8082)
s.mount("/", Tofu::Tofulet, tofu)
s.start

