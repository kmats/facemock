require 'sqlite3'
require 'facemock/database/table'
require 'facemock/database/application'
require 'facemock/database/user'
require 'facemock/database/permission'

module Facemock
  class Database
    ADAPTER = "sqlite3"
    DB_DIRECTORY = File.expand_path("../../../db", __FILE__)
    DEFAULT_DB_NAME = "facemock"
    TABLE_NAMES = [:applications, :users, :permissions]

    attr_reader :name
    attr_reader :connection

    def initialize(name=nil)
      @name = DEFAULT_DB_NAME
      connect
      create_tables
    end

    def connect
      @connection = SQLite3::Database.new filepath
      @state = :connected
      @connection
    end

    def disconnect!
      @connection.close
      @state = :disconnected
      nil
    end
      
    def connected?
      @state == :connected
    end

    def drop
      disconnect!
      File.delete(filepath) if File.exist?(filepath)
      nil
    end

    def clear
      drop_tables
      create_tables
    end

    def create_tables
      TABLE_NAMES.each do |table_name|
        self.send "create_#{table_name}_table" unless table_exists?(table_name)
      end
      true
    end

    def drop_table(table_name)
      return false unless File.exist?(filepath) && table_exists?(table_name)
      @connection.execute "drop table #{table_name};"
      true
    end

    def drop_tables
      return false unless File.exist?(filepath)
      TABLE_NAMES.each{|table_name| drop_table(table_name) }
      true
    end

    def filepath
      name ||= @name
      File.join(DB_DIRECTORY, "#{@name}.#{ADAPTER}")
    end

    def table_exists?(table_name)
      tables = @connection.execute "select * from sqlite_master"
      tables.each do |table|
        return true if table[1].to_s == table_name.to_s
      end
      false
    end

    private

    def create_applications_table
      @connection.execute <<-SQL
        CREATE TABLE applications (
          id          INTEGER   PRIMARY KEY AUTOINCREMENT,
          secret      TEXT      NOT NULL,
          created_at  DATETIME  NOT NULL,
          UNIQUE(secret)
        );
      SQL
    end

    def create_users_table
      @connection.execute <<-SQL
        CREATE TABLE users (
          id              INTEGER  PRIMARY KEY AUTOINCREMENT,
          name            TEXT      NOT NULL,
          email           TEXT      NOT NULL,
          password        TEXT      NOT NULL,
          installed       BOOLEAN   NOT NULL,
          access_token    TEXT      NOT NULL,
          application_id  INTEGER   NOT NULL,
          created_at      DATETIME  NOT NULL,
          UNIQUE(access_token));
      SQL
    end

    def create_permissions_table
      @connection.execute <<-SQL
        CREATE TABLE permissions (
          id          INTEGER   PRIMARY KEY AUTOINCREMENT,
          name        TEXT      NOT NULL,
          user_id     INTEGER   NOT NULL,
          created_at  DATETIME  NOT NULL
        );
      SQL
    end
  end
end
