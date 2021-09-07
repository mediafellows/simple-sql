# rubocop:disable Naming/UncommunicativeMethodParamName

require "forwardable"
require "logger"
require "expectation"

require_relative "sql/version"
require_relative "sql/fragment"
require_relative "sql/helpers"
require_relative "sql/result"
require_relative "sql/config"
require_relative "sql/logging"
require_relative "sql/connection"
require_relative "sql/table_print"
require_relative "sql/monkey_patches"

module Simple
  # The Simple::SQL module
  module SQL
    extend self

    extend Forwardable
    delegate [:ask, :all, :each, :exec, :locked, :lock!, :print, :transaction, :wait_for_notify, :estimate_cost] => :default_connection
    delegate [:reflection] => :default_connection
    delegate [:duplicate] => :default_connection
    delegate [:insert] => :default_connection
    delegate [:scope] => :default_connection

    delegate [:logger, :logger=] => ::Simple::SQL::Logging

    def escape_string(s)
      expect! s => [Symbol, String, nil]

      return "NULL" unless s

      "'#{PG::Connection.escape_string(s)}'"
    end

    def table_print(records, io: STDOUT, width: :auto)
      ::Simple::SQL::TablePrint.table_print(records, width: width, io: io)
      records
    end

    # connects to the database specified via the url parameter. If called
    # without argument it tries to determine a DATABASE_URL from either the
    # environment setting (DATABASE_URL) or from a config/database.yml file,
    # taking into account the RAILS_ENV and RACK_ENV settings.
    #
    # Returns the connection object.
    def connect(database_url = :auto)
      Connection.create(database_url)
    end

    def with_connection(database_url = :auto)
      connection = connect(database_url)

      yield(connection) if connection
    ensure
      connection&.disconnect!
    end

    # deprecated
    def configuration
      Config.parse_url(Config.determine_url)
    end

    # -- default connection ---------------------------------------------------

    # returns the default connection.
    def default_connection
      @default_connection ||= connect(:auto)
    end

    # connects to the database specified via the url parameter, and sets
    # Simple::SQL's default connection.
    #
    # \see connect, default_connection
    def connect!(database_url = :auto)
      disconnect!
      @default_connection = connect(database_url)
    end

    # disconnects the current default connection.
    def disconnect!
      ::Simple::SQL::ConnectionManager.disconnect_all!
      @default_connection = nil
    end
  end
end
