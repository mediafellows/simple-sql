require "spec_helper"

# Dummy config class for ERB tests below
module DatabaseConfig
  extend self

  def host
    '127.0.0.1'
  end

  def port
    '5432'
  end

  def username
    'some-user'
  end

  def password
    'secret-pw'
  end

  def database
    'some-db'
  end
end

describe "Simple::SQL::Config" do
  describe ".determine_url" do
    it "Reads from config/database.yml if no path is provided" do
      # we can't test full string here as local dev database.yml can be individual
      expect(SQL::Config.determine_url).to include("@127.0.0.1:5432/simple-sql-test")
    end

    it 'Correctly parses provided database.yml (even if it contains ERB template values)' do
      expect(SQL::Config.determine_url(path: 'config/test-database.yml')).to eq('postgres://some-user:secret-pw@127.0.0.1:5432/some-db')
    end
  end

  describe ".parse_url" do
    it "parses a DATABASE_URL" do
      parsed = SQL::Config.parse_url "postgres://foo:bar@server/database"
      expect(parsed).to eq(
        dbname: "database",
        host: "server",
        password: "bar",
        sslmode: "prefer",
        user: "foo"
      )
    end

    it "may enforce SSL" do
      parsed = SQL::Config.parse_url "postgress://foo:bar@server/database"
      expect(parsed).to eq(
        dbname: "database",
        host: "server",
        password: "bar",
        sslmode: "require",
        user: "foo"
      )
    end
  end
end
