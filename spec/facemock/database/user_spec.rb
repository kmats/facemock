require 'spec_helper'

describe Facemock::Database::User do
  include TableHelper

  let(:db_name)        { ".test" }
  let(:table_name)     { :users }
  let(:column_names)   { [ :id,
                           :name,
                           :email,
                           :password,
                           :installed,
                           :access_token,
                           :application_id,
                           :created_at ] }
  let(:children)       { [ Facemock::Database::Permission, 
                           Facemock::Database::AuthorizationCode ] }

  let(:id)             { 1 }
  let(:name)           { "test user" }
  let(:email)          { "hoge@fugapiyo.com" }
  let(:password)       { "testpass" }
  let(:installed)      { true }
  let(:access_token)   { "test_token" }
  let(:application_id) { 1 }
  let(:created_at)     { Time.now }
  let(:options)        { { id:             id, 
                           name:           name,
                           email:          email,
                           password:       password,
                           installed:      installed,
                           access_token:   access_token,
                           application_id: application_id,
                           created_at:     created_at } }

  after { remove_dynamically_defined_all_method }

  describe '::TABLE_NAME' do
    subject { Facemock::Database::User::TABLE_NAME }
    it { is_expected.to eq table_name }
  end

  describe '::COLUMN_NAMES' do
    subject { Facemock::Database::User::COLUMN_NAMES }
    it { is_expected.to eq column_names }
  end

  describe '::CHILDREN' do
    subject { Facemock::Database::User::CHILDREN }
    it { is_expected.to eq children }
  end

  describe '#initialize' do
    context 'without option' do
      subject { Facemock::Database::User.new }
      it { is_expected.to be_kind_of Facemock::Database::User }

      describe '.id' do
        subject { Facemock::Database::User.new.id }
        it { is_expected.to be > 0 }
        it { is_expected.to be < 100010000000000 }
      end

      describe '.name' do
        subject { Facemock::Database::User.new.name }
        it { is_expected.to be_kind_of String }

        describe '.size' do
          subject { Facemock::Database::User.new.name.size }
          it { is_expected.to be <= 10 }
        end
      end

      describe '.email' do
        before { @user = Facemock::Database::User.new }
        subject { @user.email }
        it { is_expected.to be_kind_of String }
        it { is_expected.to eq "#{@user.name}@example.com" }
      end

      describe '.password' do
        subject { Facemock::Database::User.new.password }
        it { is_expected.to be_kind_of String }

        describe '.size' do
          subject { Facemock::Database::User.new.password.size }
          it { is_expected.to be <= 10 }
        end
      end

      describe '.installed' do
        subject { Facemock::Database::User.new.installed }
        it { is_expected.to eq false }
      end

      describe '.access_token' do
        subject { Facemock::Database::User.new.access_token }
        it { is_expected.to be_kind_of String }

        describe '.size' do
          subject { Facemock::Database::User.new.access_token.size }
          it { is_expected.to eq 128 }
        end
      end

      describe '.application_id' do
        subject { Facemock::Database::User.new.application_id }
        it { is_expected.to be_nil }
      end

      describe '.created_at' do
        subject { Facemock::Database::User.new.created_at }
        it { is_expected.to be_nil }
      end
    end

    context 'with id option but it is not integer' do
      before { @opts = { id: "test_id" } }
      subject { Facemock::Database::User.new(@opts) }
      it { is_expected.to be_kind_of Facemock::Database::User }

      describe '.id' do
        subject { Facemock::Database::User.new(@opts).id }
        it { is_expected.to be > 0 }
        it { is_expected.to be < 100010000000000 }
      end
    end

    context 'with application_id option but it is not integer' do
      before { @opts = { application_id: "test_id" } }
      subject { Facemock::Database::User.new(@opts) }
      it { is_expected.to be_kind_of Facemock::Database::User }

      describe '.application_id' do
        subject { Facemock::Database::User.new(@opts).application_id }
        it { is_expected.to be_nil }
      end
    end

    context 'with name option' do
      before do
        @name = "test user"
        @opts = { name: @name }
      end
      subject { Facemock::Database::User.new(@opts) }
      it { is_expected.to be_kind_of Facemock::Database::User }

      context '.name' do
        subject { Facemock::Database::User.new(@opts).name }
        it { is_expected.to eq @name }
      end

      context '.email' do
        subject { Facemock::Database::User.new(@opts).email }
        it { is_expected.to eq @name.gsub(" ", "_") + "@example.com" }
      end
    end

    context 'with all options' do
      subject { Facemock::Database::User.new(options) }
      it { is_expected.to be_kind_of Facemock::Database::User }

      context 'then attributes' do
        it 'should set specified value by option' do
          column_names.each do |column_name|
            value = Facemock::Database::User.new(options).send(column_name)
            expect(value).to eq options[column_name]
          end
        end
      end
    end
  end

  describe 'destroy' do
    before do
      stub_const("Facemock::Database::DEFAULT_DB_NAME", db_name)
      @database = Facemock::Database.new
    end
    after { @database.drop }

    context 'when has permission and authorizaion_code' do
      before do
        application = Facemock::Database::Application.create!
        @user = Facemock::Database::User.create!(application_id: application.id)
        permission = Facemock::Database::Permission.new(name: "email", user_id: @user.id)
        permission.save!
        authorization_code = Facemock::Database::AuthorizationCode.new(user_id: @user.id)
        authorization_code.save!
      end

      it 'should delete permissions' do
        @user.destroy
        permissions = Facemock::Database::Permission.find_all_by_user_id(@user.id)
        expect(permissions).to be_empty
        authorization_codes = Facemock::Database::AuthorizationCode.find_all_by_user_id(@user.id)
        expect(authorization_codes).to be_empty
      end
    end
  end
end
