# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Layout/AlignHash

# module to determine database configuration
module Simple::SQL::Config
  extend self

  def set_environment!(env_name = nil)
    env_name ||= ENV["POSTJOB_ENV"] || ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

    require "yaml"
    configs = YAML.load_file "config/database.yml"
    config = configs.fetch(env_name) { configs.fetch("defaults") }

    Simple::SQL.logger.info "Read database config #{config.inspect}"

    ENV["PGHOST"]     = config["host"]
    ENV["PGPORT"]     = config["port"] && config["port"].to_s
    ENV["PGUSER"]     = config["username"]
    ENV["PGPASSWORD"] = config["password"]
    ENV["PGDATABASE"] = config["database"]
  end

  # parse a DATABASE_URL, return PG::Connection settings.
  def parse_url(url)
    expect! url => /^postgres(ql)?s?:\/\//

    require "uri"
    uri = URI.parse(url)
    raise ArgumentError, "Invalid URL #{url}" unless uri.hostname && uri.path

    config = {
      dbname: uri.path.sub(%r{^/}, ""),
      host:   uri.hostname
    }
    config[:port] = uri.port if uri.port
    config[:user] = uri.user if uri.user
    config[:password] = uri.password if uri.password
    config[:sslmode] = uri.scheme == "postgress" || uri.scheme == "postgresqls" ? "require" : "prefer"
    config
  end

  # determines the database_url from either the DATABASE_URL environment setting
  # or a config/database.yml file.
  def determine_url
    ENV["DATABASE_URL"] || database_url_from_database_yml
  end

  private

  def database_url_from_database_yml
    abc = read_database_yml
    username, password, host, port, database = abc.values_at "username", "password", "host", "port", "database"

    URI::Generic.build(
      scheme: "postgres",
      userinfo: [username, (":" if password), password].join,
      host: host || "localhost",
      port: port,
      path: "/#{database}"
    ).to_s
  end

  def read_database_yml
    require "yaml"
    database_config = YAML.load_file "config/database.yml"
    env = ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

    database_config[env] ||
      database_config["defaults"] ||
      raise("Invalid or missing database configuration in config/database.yml for #{env.inspect} environment")
  end
end
