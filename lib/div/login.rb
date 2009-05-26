require 'div/div'

module Div 
  class Login
    def initialize
      @user = nil
    end
    attr_reader :user

    def name; @user.to_s; end

    def guest_login
      login(guest_user)
    end

    def guest?
      @user == guest_user
    end

    def login(user)
      @user = user
    end
    
    def login?
      ! @user.nil?
    end
    
    def logout
      @user = nil
    end

    def get_user(user, pass)
      nil
    end

    def guest_user
      'guest'
    end
  end

  class LoginDiv < Div
    def initialize(session, db, hint)
      super(session)
      @login = db
      @hint = hint
    end

    def to_args(params)
      user ,= params['user']
      pass ,= params['pass']

      if user
	user = user.sub(/^(\s+)/, '').sub(/(\s+)$/, '')
      end

      return user, pass
    end

    def do_login(context, params)
      user , pass = to_args(params)
      @hint = user
      user = @login.get_user(user, pass)
      @login.login(user)
    end

    def do_logout(context, params)
      @hint = nil
      @login.logout
    end

    def do_guest(context, params)
      @login.guest_login
    end
  end
end

