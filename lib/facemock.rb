require 'facemock/version'
require 'facemock/config'
require 'facemock/fb_graph'
require 'facemock/omniauth'
require 'facemock/database'
require 'facemock/errors'
require 'facemock/application'
require 'facemock/user'
require 'facemock/permission'
require 'facemock/authorization_code'
require 'facemock/login'
require 'facemock/authentication'

module Facemock 
  extend self

  def on
    Facemock::FbGraph.on
  end

  def off
    Facemock::FbGraph.off
  end

  def on?
    FbGraph == Facemock::FbGraph
  end

  def auth_hash(access_token=nil)
    if access_token.kind_of?(String) && access_token.size > 0
      user = Facemock::User.find_by_access_token(access_token)
      if user
        Facemock::OmniAuth::AuthHash.new({
          provider:    "facebook",
          uid:         user.id,
          info:        { name:     user.name },
          credentials: { token:    access_token, expires_at: Time.now + 60.days },
          extra:       { raw_info: { id: user.id, name: user.name } }
        })
      else
        Facemock::OmniAuth::AuthHash.new
      end
    else
      Facemock::OmniAuth::AuthHash.new
    end
  end
end
