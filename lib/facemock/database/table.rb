require 'facemock/database'
require 'sqlite3'
require 'hashie'
require 'pry'

module Facemock
  class Database
    class Table
      TABLE_NAME = :tables
      COLUMN_NAMES = [:id, :created_at]

      def initialize(options={})
        opts = Hashie::Mash.new(options)
        @id = opts.id
        @created_at = opts.created_at
      end

      # 独自実装部分 (ActiveRecordだと主キーはセットしても無視されるっぽい挙動
      #   @id に値が設定されていない場合はinsert
      #   @id に値が設定されていて、そのidのレコードが無い場合はinsert
      #   @id に値が設定されていて、そのidのレコードが有る場合はupdate
      def save!
        if @id && !(self.class.find_by_id(@id).nil?)
          update!
        else
          insert!
        end
      end

      def update_attributes!(options)
        # カラムに含まれるかどうかの確認。なければNoMethodError
        options.each_key {|key| self.send(key) }
        update!(options)
      end

      def destroy
        execute "delete from #{table_name} where id = #{@id};"
        fetch
      end

      def fetch
        records = execute "select * from #{table_name} where id = #{@id} limit 1;"

        return nil unless record = records.first
        (0...column_names.size).each do |index|
          method_name = column_names[index].to_s + "="
          if column_names[index] == :created_at
            self.send(method_name, Time.parse(record[index]))
          else
            self.send(method_name, record[index])
          end
        end
        self
      end

      def method_missing(name, *args)
        method_name = name.to_s.include?("=") ? name.to_s[0...-1].to_sym : name
        case name
        when :identifier  then return send(:id)
        when :identifier= then return send(:id=, *args)
        else
          if column_names.include?(method_name) && args.size <= 1
            if !name.to_s.include?("=") && args.empty?
              define_column_getter(name)
              return send(name)
            else
              define_column_setter(name)
              return send(name, args.first)
            end
          else
            super
          end
        end
      end

      def self.all
        records = execute "select * from #{table_name};"
        records_to_objects(records)
      end

      def self.first
        records = execute "select * from #{table_name} limit 1;"
        record_to_object(records.first)
      end

      def self.last
        records = execute "select * from #{table_name} order by id desc limit 1 ;"
        record_to_object(records.first)
      end

      def self.where(column)
        column_name = column.keys.first
        value = column.values.first
        column_value = (value.kind_of?(String)) ? "'" + value + "'" : value.to_s

        records = execute "select * from #{table_name} where #{column_name} = #{column_value};"
        records_to_objects(records)
      end

      def self.method_missing(name, *args)
        case name
        when /^find_by_(.+)/
          column_name = $1
          super unless column_names.include?(column_name.to_sym)
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" unless args.size == 1
          define_find_by_column(column_name)
          send(name, args.first)
        when /^find_all_by_(.+)/
          column_name = $1
          super unless column_names.include?(column_name.to_sym)
          raise ArgumentError, "wrong number of arguments (#{args.size} for 1)" unless args.size == 1
          define_find_all_by_column(column_name)
          send(name, args.first)
        else
          super
        end
      end

      private

      def execute(sql)
        self.class.execute(sql)
      end

      # WANT : executeした結果をhashにしたい。扱いにくい
      def self.execute(sql)
        @db = Facemock::Database.new
        records = @db.connection.execute sql
        if records.empty? && sql =~ /^insert /
          records = @db.connection.execute <<-SQL
            select * from #{table_name} where ROWID = last_insert_rowid();
          SQL
        end
        @db.disconnect!
        records
      end

      def self.record_to_object(record)
        return nil unless record
        options = {}
        column_names.each_with_index do |column_name, index|
          value = record[index]

          options[column_name] = case column_name
          when :created_at then Time.parse(value)
          else
            ["true", "false"].include?(value) ? eval(value) : value
          end
        end
        self.new(options)
      end

      def self.records_to_objects(records)
        records.inject([]) do |objects, record|
          objects << record_to_object(record)
        end
      end

      def self.define_find_by_column(column_name)
        self.class_eval <<-EOF
          def self.find_by_#{column_name}(value)
            column_value = case value
            when String then "'" + value + "'"
            when Time   then "'" + value.to_s + "'"
            else value.to_s
            end

            select_string = "select * from #{table_name} where #{column_name} = "
            select_string += column_value + " limit 1";
            records = execute select_string
            record_to_object(records.first)
          end
        EOF
      end

      def self.define_find_all_by_column(column_name)
        self.class_eval <<-EOF
          def self.find_all_by_#{column_name}(value)
            column_value = case value
            when String then "'" + value + "'"
            when Time   then "'" + value.to_s + "'"
            else value.to_s
            end

            select_string = "select * from #{table_name} where #{column_name} = "
            select_string += column_value;
            records = execute select_string
            records_to_objects(records)
          end
        EOF
      end

      def define_column_getter(name)
        self.class.class_eval <<-EOF
          def #{name}
            self.instance_variable_get(:@#{name})
          end
        EOF
      end

      def define_column_setter(name)
        self.class.class_eval <<-EOF
          def #{name}(value)
            instance_variable_set(:@#{name.to_s.gsub("=", "")}, value)
          end
        EOF
      end

      def insert!
        # idが指定されていない場合の対応
        target_column_names = if self.send(:id)
          column_names
        else
          column_names.select{|name| name != :id}
        end

        self.created_at = Time.now
        target_column_values = target_column_names.inject([]) do |ary, column_name|
          ary << "'#{self.send(column_name)}'"
        end
        values  = target_column_values.join(", ")
        columns = target_column_names.join(', ')

        records = execute "insert into #{table_name}(#{columns}) values ( #{values} );"
        @id = records.first.first
        @created_at = Time.parse(records.first.last)
        self
      end

      def update!(options={})
        # TODO : デフォルト値をDBで持つような場合に未対応
        # save! から叩かれた場合はここを通る。created_atやその他のcolum値を設定する
        if options.empty?
          column_names.each do |column_name|
            if (value = self.send(column_name)) && column_name != :id
              options[column_name] = value
            end
          end
        end

        unless options.empty?
          target_key_values = options.inject([]) do |ary, (key, value)|
            ary << case value
            when String, Time          then "#{key} = '#{value}'"
            when TrueClass, FalseClass then "#{key} = #{((value) ? 1 : 0)}"
            end
          end

          sql = "update #{table_name} set #{target_key_values.join(', ')} where id = #{@id};"
          execute sql
        end
        fetch
      end

      def table_name
        self.class.table_name
      end

      def column_names
        self.class.column_names
      end

      def self.table_name
        self::TABLE_NAME
      end

      def self.column_names
        self::COLUMN_NAMES
      end
    end
  end
end
