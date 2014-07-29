require 'active_record'
require 'hashie'
require 'facemock/fb_graph/application/user/right'

module Facemock
  module FbGraph
    class Application < ActiveRecord::Base
      class User < ActiveRecord::Base
        self.table_name = "users"
        alias_attribute  :identifier, :id
        has_many :rights, :dependent => :destroy
        attr_reader :permissions

        def initialize(options={})
          opts = Hashie::Mash.new(options)
          identifier   = opts.identifier   || ("10000" + (0..9).to_a.shuffle[0..10].join).to_i
          name         = opts.name         || rand(36**10).to_s(36)
          email        = opts.email        || name.gsub(" ", "_") + "@example.com"
          password     = opts.password     || rand(36**10).to_s(36)
          installed    = opts.installed    || false
          access_token = opts.access_token || Digest::SHA512.hexdigest(identifier.to_s)
          @permissions = []

          super(
            :name         => name,
            :email        => email,
            :password     => password,
            :installed    => installed,
            :access_token => access_token
          )
          self.id = identifier
          if opts.permissions
            build_rights(opts.permissions)
            set_permissions
          elsif opts.application_id
            self.application_id = opts.application_id
          end
        end

        def fetch
          User.find_by_id(self.id)
        end

        def revoke!
          self.rights.each{|right| right.destroy}
          @permissions = []
        end

        private

        def set_permissions
          @permissions = self.rights.inject([]) do |simbols, right|
            simbols << right.name.to_sym
          end
          @permissions.uniq!
        end

        def build_rights(permissions_string)
          permissions_string.gsub(/\s/, "").split(",").uniq.each do |permission_name|
            unless self.rights.find{|perm| perm.name == permission_name}
              self.rights.build(name: permission_name)
            end
          end
        end
      end
    end
  end
end
