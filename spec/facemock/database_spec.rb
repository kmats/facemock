require 'spec_helper'

describe Facemock::Database do
  let(:db_name)         { ".test" }
  let(:default_db_name) { "facemock" }
  let(:adapter)         { "sqlite3" }
  let(:db_directory)    { File.expand_path("../../../db", __FILE__) }
  let(:db_filepath)     { File.join(db_directory, "#{db_name}.#{adapter}") }

  describe '::ADAPTER' do
    subject { Facemock::Database::ADAPTER }
    it { is_expected.to eq adapter }
  end

  describe '::DB_DIRECTORY' do
    subject { Facemock::Database::DB_DIRECTORY }
    it { is_expected.to eq db_directory }
  end

  describe '::DEFAULT_DB_NAMES' do
    subject { Facemock::Database::DEFAULT_DB_NAME }
    it { is_expected.to eq default_db_name }
  end

  describe '#initialize' do
    before do
      allow_any_instance_of(Facemock::Database).to receive(:connect) { true }
      allow_any_instance_of(Facemock::Database).to receive(:create_tables) { true }
    end

    subject { lambda { Facemock::Database.new } }
    it { is_expected.not_to raise_error }

    describe '.name' do
      subject { Facemock::Database.new.name }
      it { is_expected.to eq default_db_name }
    end
  end

  describe '#connect' do
    before do
      allow_any_instance_of(Facemock::Database).to receive(:create_tables) { true }
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    subject { lambda { @database.connect } }
    it { is_expected.not_to raise_error }
    it { expect(File.exist?(@database.filepath)).to eq true }
  end

  describe '#disconnect' do
    before do
      allow_any_instance_of(Facemock::Database).to receive(:create_tables) { true }
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    subject { lambda { @database.disconnect! } }
    it { is_expected.not_to raise_error }

    context 'when success' do
      describe 'datbase file is not removed' do
        before { @database.disconnect! }
        it { expect(File.exist?(@database.filepath)).to eq true }
      end
    end
  end

  describe '#connected?' do
    before do
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    context 'after new' do
      subject { @database.connected? }
      it { is_expected.to eq true }
    end

    context 'after disconnect!' do
      before do
        @database.disconnect!
      end

      subject { @database.connected? }
      it { is_expected.to eq false }
    end

    context 'after connect' do
      before do
        @database.disconnect!
        @database.connect
      end

      subject { @database.connected? }
      it { is_expected.to eq true }
    end
  end

  describe '#drop' do
    before do
      allow_any_instance_of(Facemock::Database).to receive(:create_tables) { true }
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    subject { lambda { @database.drop } }
    it { is_expected.not_to raise_error }

    context 'when success' do
      describe 'database file does not exist' do
        before { @database.drop }
        it { expect(File.exist?(@database.filepath)).to eq false }
      end

      describe 're-drop is success' do
        before { @database.drop }
        subject { lambda { @database.drop } }
        it { is_expected.not_to raise_error }
      end
    end
  end

  describe '#clear' do
    before do
      allow_any_instance_of(Facemock::Database).to receive(:create_tables) { true }
      @database = Facemock::Database.new(db_name)
      expect(@database).to receive(:drop_tables)
      expect(@database).to receive(:create_tables)
    end
    after { @database.drop }

    subject { @database.clear }
    it { is_expected.to be_truthy }
  end

  describe '#create_tables' do
    before do
      @database = Facemock::Database.new(db_name)
      @database.drop_tables
    end
    after { @database.drop }

    subject { lambda { @database.create_tables } }
    it { is_expected.not_to raise_error }
  end

  describe '#drop_table' do
    before do
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    context 'when table exist' do
      it 'should return true' do
        Facemock::Database.tables.each do |table_name|
          expect(@database.drop_table(table_name)).to eq true
        end
      end
    end

    context 'when table does not exist' do
      it 'should return true' do
        @database.drop_tables
        Facemock::Database.tables.each do |table_name|
          expect(@database.drop_table(table_name)).to eq false
        end
      end
    end

    context 'when database does not exist' do
      it 'should return false' do
        @database.drop
        Facemock::Database.tables.each do |table_name|
          expect(@database.drop_table(table_name)).to eq false
        end
      end
    end
  end

  describe '#drop_tables' do
    before do
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    context 'when table exist' do
      subject { @database.drop_tables }
      it { is_expected.to eq true }
    end

    context 'when table does not exist' do
      before { Facemock::Database.tables.each{|table_name| @database.drop_table(table_name)} }
      subject { @database.drop_tables }
      it { is_expected.to eq true }
    end

    context 'when database does not exist' do
      before { @database.drop }
      subject { @database.drop_tables }
      it { is_expected.to eq false }
    end
  end

  describe '#filepath' do
    before do
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    subject { @database.filepath }
    it { is_expected.to eq db_filepath }

    context 'then database file is exist' do
      subject { File.exist? @database.filepath }
      it { is_expected.to eq true }
    end
  end

  describe '#table_exists?' do
    before do
      @database = Facemock::Database.new(db_name)
    end
    after { @database.drop }

    context 'when new' do
      it 'should exist all tables' do
        Facemock::Database.tables.each do |table_name|
          expect(@database.table_exists?(table_name)).to eq true
        end
      end
    end

    context 'when drop tables' do
      before { @database.drop_tables }

      it 'should not exist any tables' do
        Facemock::Database.tables.each do |table_name|
          expect(@database.table_exists?(table_name)).to eq false
        end
      end
    end
  end
end
