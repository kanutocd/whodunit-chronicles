# frozen_string_literal: true

module SQLite3
  class Database
    attr_reader :path, :calls

    def initialize(path)
      @path = path
      @calls = []
    end

    def execute(sql, binds = nil)
      @calls << [sql, binds]
      return [['whodunit_chronicles_entries']] if sql.include?('sqlite_master')
      return [[0]] if sql.include?('COUNT(*)')

      []
    end
  end
end
