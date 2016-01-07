require 'drip'
require 'singleton'
require 'thread'

class NazoStore
  def initialize(drip)
    @drip = drip
    @timeline = []
    @nazo = []
  end

  def add_text(str, sign)
    @timeline << [str, sign, Time.now]
    @timeline.size - 1
  end

  def add_nazo(qutestion, choose, sign)
    @nazo << [question, choose, sign]
    @nazo.size - 1
  end
  
  def each_text
    return to_enum(__method__) unless block_given?
    @timeline.reverse_each do |x|
      yield(x)
    end
  end
  
  def nazo
    idx = rand(@nazo.size)
    @nazo[idx]
  end
end

