class Simple::SQL::Connection
  #
  # Creates duplicates of record in a table.
  #
  # This method handles timestamp columns (these will be set to the current
  # time) and primary keys (will be set to NULL.) You can pass in overrides
  # as a third argument for specific columns.
  #
  # Parameters:
  #
  # - ids: (Integer, Array<Integer>) primary key ids
  # - overrides: Hash[column_names => SQL::Fragment]
  #
  def duplicate(table, ids, overrides = {})
    ids = Array(ids)
    return [] if ids.empty?

    Duplicator.new(self, table, overrides).call(ids)
  end

  class Duplicator
    attr_reader :connection, :table_name, :custom_overrides

    def initialize(connection, table_name, overrides)
      @connection       = connection
      @table_name       = table_name
      @custom_overrides = validated_overrides(overrides)
    end

    def call(ids)
      connection.all query, ids
    rescue PG::UndefinedColumn => e
      raise ArgumentError, e.message
    end

    private

    # This stringify all keys of the overrides hash, and verifies that
    # all values in there are SQL::Fragments
    def validated_overrides(overrides)
      overrides.inject({}) do |hsh, (key, value)|
        unless value.is_a?(::Simple::SQL::Fragment)
          raise ArgumentError, "Pass in override values via SQL.fragment (for #{value.inspect})"
        end

        hsh.update key.to_s => value.to_sql
      end
    end

    def timestamp_overrides
      reflection = connection.reflection
      reflection.timestamp_columns(table_name).inject({}) do |hsh, column|
        hsh.update column => "now() AS #{column}"
      end
    end

    def copy_columns
      reflection = connection.reflection
      (reflection.columns(table_name) - reflection.primary_key_columns(table_name)).inject({}) do |hsh, column|
        hsh.update column => column
      end
    end

    # build SQL query
    def query
      sources = {}

      sources.update copy_columns
      sources.update timestamp_overrides
      sources.update custom_overrides

      # convert into an Array, to make sure that keys and values aka firsts
      # and lasts are always in the correct order.
      sources = sources.to_a

      <<~SQL
        INSERT INTO #{table_name}(#{sources.map(&:first).join(', ')})
          SELECT #{sources.map(&:last).join(', ')}
          FROM #{table_name}
          WHERE id = ANY($1) RETURNING id
      SQL
    end
  end
end
