require 'facemock/database'
require 'facemock/database/table'
require 'sqlite3'
require 'hashie'

module Facemock
  class Database
    class Application < Table
      TABLE_NAME = :applications
      COLUMN_NAMES = [:id, :secret, :created_at]

      def initialize(options={})
        opts = Hashie::Mash.new(options)
        @id         = opts.id     || (0..9).to_a.shuffle[0..15].join
        @secret     = opts.secret || Digest::SHA512.hexdigest(identifier.to_s)
        @created_at = opts.created_at
      end
    end
  end
end
