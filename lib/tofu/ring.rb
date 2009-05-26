require 'rinda/ring'

module Tofu
  class RingTofuletFinder
    def initialize(ts=nil)
      ts = Rinda::RingFinger.primary unless ts
      @notify = ts.notify('write', [:name, :Tofulet, nil, nil])
      @all = ts.read_all([:name, :Tofulet, nil, nil])
    end
    
    def mount(point, bartender)
      self.each do |tuple|
	begin
	  webrick = tuple[2]
	  webrick.mount(point, DRbObject.new(bartender))
	rescue
	end
      end
    end

    def each(&blk)
      @all.each(&blk)
      @notify.each do |ev, tuple|
      yield(tuple)
      end
    end
  end

  class RingTofuletProvider
    include DRbUndumped
    def initialize(webrick, ts=nil)
      @webrick = webrick
      @ts = ts || Rinda::RingFinger.primary
      @renewer = Rinda::SimpleRenewer.new
    end
    
    def join(desc = 'tofu-runner')
      @ts.write([:name, :Tofulet, self, desc], @renewer)
    end
    
    def mount(point, bartender)
      @webrick.unmount(point)
      @webrick.mount(point, WEBrick::Tofulet, bartender)
    end
  end
end


