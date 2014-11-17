require 'nkf'
require 'uri'

module Tofu
  class Div
    def update_js
      <<-"EOS"
      function div_x_eval(div_id) {
        var ary = document.getElementsByName(div_id + "div_x_eval");
        for (var j = 0; j < ary.length; j++) {
          var div_arg = ary[j];
          for (var i = 0; i < div_arg.childNodes.length; i++) {
            var node = div_arg.childNodes[i];
            if (node.attributes.getNamedItem('name').nodeValue == 'div_x_eval') {
              var script = node.attributes.getNamedItem('value').nodeValue;
              try {
                 eval(script);
              } catch(e) {
              }
            }
          }
        }
      }

      function div_x_update(div_id, url) {
        var x;
        try {
          x = new ActiveXObject("Msxml2.XMLHTTP");
        } catch (e) {
          try {
            x = new ActiveXObject("Microsoft.XMLHTTP");
          } catch (e) {
            x = null;
          }
        }
        if (!x && typeof XMLHttpRequest != "undefined") {
           x = new XMLHttpRequest();
        }
        if (x) {
          x.onreadystatechange = function() {
            if (x.readyState == 4 && x.status == 200) {
              var div = document.getElementById(div_id);
              div.innerHTML = x.responseText;
              div_x_eval(div_id);
            }
          }
          x.open("GET", url);
          x.send(null);
        }
      }
EOS
    end

    def a_and_update(method_name, add_param, context, target=nil)
      target ||= self
      param = {
        'div_inner_id' => target.div_id
      }
      param.update(add_param)

      param = make_param(method_name, param)
      ary = param.collect do |k, v|
	"#{u(k)}=#{u(v)}"
      end
      path = URI.parse(context.req_absolute_path)
      url = path + %Q!#{action(context)}?#{ary.join(';')}!
      %Q!div_x_update("#{target.div_id}", #{url.to_s.dump});!
    end

    def on_update_script(ary_or_script)
      ary = if String === ary_or_script
              [ary_or_script]
            else
              ary_or_script
            end
      str = %Q!<form name="#{div_id}div_x_eval">!
      ary.each do |script|
        str << %Q!<input type='hidden' name='div_x_eval' value="#{script.gsub('"', '&quot;')}" />!
      end
      str << '</form>'
      str
    end

    def update_me(context)
      a_and_update('else', {}, context)
    end

    def update_after(msec, context)
      callback = update_me(context)
      script = %Q!setTimeout(#{callback.dump}, #{msec})!
      on_update_script(script)
    end
  end
  
  class Session
    def do_inner_html(context)
      params = context.req_params
      div_id ,= params['div_inner_id']
      return false unless div_id

      div = fetch(div_id)
      body = div ? NKF.nkf('-w8dXm0', div.to_html(context)) : ''

      context.res_header('content-type', 'text/html; charset=utf-8')
      context.res_body(body)

      return true
    end
  end
end


