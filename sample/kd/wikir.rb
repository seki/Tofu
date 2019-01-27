require 'tofu'
require 'kramdown'
require 'singleton'

module WikiR
  class Book
    include Singleton

    def initialize
      @monitor = Monitor.new
      @pages = {}
    end

    def [](name)
      @pages[name] || Page.new(name)
    end

    def []=(name, src)
      @monitor.synchronize do
        page = self[name]
        @pages[name] = page
        page.src = src
      end
    end
  end

  class Page
    def initialize(name)
      @name = name
      self.src = "# #{name}\n\nan empty page. edit me."
    end
    attr_reader :name, :src, :html, :warnings

    def src=(text)
      @src = text
      document = Kramdown::Document.new(text)
      @html = document.to_html
      @warnings = document.warnings
    end
  end
end

class WikiRSession < Tofu::Session
  def initialize(bartender, hint=nil)
    super
    @book = WikiR::Book.instance
    @base = BaseTofu.new(self)
  end
  attr_reader :book

  def lookup_view(context)
    @base
  end

  def do_GET(context)
    context.res_header('pragma', 'no-cache')
    context.res_header('cache-control', 'no-cache')
    context.res_header('expires', 'Thu, 01 Dec 1994 16:00:00 GMT')
    super(context)
  end
end

class BaseTofu < Tofu::Tofu
  set_erb('base.erb')
  
  def initialize(session)
    super(session)
    @wiki = WikiTofu.new(session)
  end
end

class WikiTofu < Tofu::Tofu
  set_erb('wiki.erb')

  def book
    @session.book
  end
  
  def do_edit(context, params)
    text ,= params['text']
    return if text.nil? || text.empty?
    text = text.force_encoding('utf-8')
    name ,= params['name']
    return if name.nil? || name.empty?
    name = name.force_encoding('utf-8')
    book[name] = text
  end

  def page(context)
    book[context.req_path_info]
  end
end

module Tofu
def reload_erb
  p 1
  ObjectSpace.each_object(Class) do |o|
    if o.ancestors.include?(::Tofu::Tofu)
      o.reload_erb
    end
  end
end
module_function :reload_erb
end

class MyTofulet < Tofu::CGITofulet
  def [](key)
    WikiR::Book.instance if key == 'book'
  end

  def reload_erb
    Tofu::reload_erb
  end
end

WEBrick::Daemon.start unless $DEBUG
tofu = Tofu::Bartender.new(WikiRSession, 'wikir_8083')
uri = ARGV.shift || 'druby://localhost:54322'
DRb.start_service(uri, MyTofulet.new(tofu))
s = WEBrick::HTTPServer.new(:Port => 8083)
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
tofu = Tofu::Bartender.new(WikiRSession, 'wikir_' + uri.split(':').last)
DRb.start_service(uri, MyTofulet.new(tofu))

unless $DEBUG
  STDIN.reopen('/dev/null')
  STDOUT.reopen('/dev/null', 'w')
  STDERR.reopen('/dev/null', 'w')
end

DRb.thread.join
=end
