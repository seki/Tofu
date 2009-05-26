require 'tofu/tofu'

module Div

  class TofuSession < Tofu::Session
    include MonitorMixin

    def initialize(bartender, hint=nil)
      super(bartender)
      @contents = {}
      @hint = hint
    end
    attr_accessor :hint

    def service(context)
      case context.req_method
      when 'GET', 'POST', 'HEAD'
	do_GET(context)
      else
	context.res_method_not_allowed
      end
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

    # Div::Session interface
    def action
      ""
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

end
