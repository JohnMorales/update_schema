#!/usr/bin/env ruby

require 'yaml'
require 'pry'
require 'mysql2'

class DatabaseClient
  def confirm_version_table
   execute_sql(self.class::CREATE_VERSION_TABLE)
  end

  def get_applied_scripts
    get_single_column self.class::GET_APPLIED_SCRIPTS
  end

  def apply_script sql_script_file
    sql_text = File.read(sql_script_file)
    sql_chunks = sql_text.split(/;/)
    begin_trans
    sql_chunks.each do |hunk|
      execute_sql hunk
    end
    record_script_applied sql_script_file
    commit_trans
  rescue
      rollback_trans
      raise
  end

  def begin_trans
    execute_sql "BEGIN"
  end

  def commit_trans
    execute_sql "COMMIT"
  end

  def rollback_trans
    execute_sql "ROLLBACK"
  end

  def record_script_applied file
     raise ArgumentError, "Must be implemented in a subclass since not all database clients support prepared statements."
  end

  class << self
    def load configuration
      if configuration["adapter"] == "mysql2"
        MysqlSqlDatabaseClient.new configuration
      end
    end
  end
end

class MysqlSqlDatabaseClient < DatabaseClient

  # This script will create the tracking table if it doesn't already exist.
  CREATE_VERSION_TABLE =<<CREATE_VERSION_TABLE
  CREATE TABLE IF NOT EXISTS schema_version
  (
    id int UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    script_name varchar(200),
    applied_timestamp timestamp
  )
CREATE_VERSION_TABLE

  # This script returns the array of applied scripts.
  GET_APPLIED_SCRIPTS =<<GET_APPLIED_SCRIPTS
  SELECT script_name from
  schema_version
GET_APPLIED_SCRIPTS

  def initialize configuration
    @client = Mysql2::Client.new(configuration)
  end

  def execute_sql sql_text
    @client.query(sql_text)
  end

  # Returns a single column as a vector/array.
  def get_single_column sql_text
    @client.query(sql_text, :as => :array).map{ |row| row[0] }
  end

  def record_script_applied sql_file
    # Since mysql2 does not support parameterized queries, we're inlining the SQL statement.
    execute_sql "insert into schema_version (script_name, applied_timestamp) values ('#{sql_file}', NOW())"
  end
end

USAGE=<<USAGE
usage: update_schema schema_dir
 Where schema_dir contains a database configuration file (database.yml) and SQL script files.
USAGE

schema_dir = ARGV[0]
unless schema_dir && Dir.exists?(schema_dir)
  puts USAGE
  exit 1
end

schema_dir = schema_dir.chomp('/')
environment = ENV['APP_ENV'] || "development"
database_yml = "#{schema_dir}/database.yml"

unless File.exists? database_yml
  puts "Could not find #{database_yml}", USAGE
  exit 2
end

database_config = YAML.load_file(database_yml)[environment]
db = DatabaseClient.load(database_config)

db.confirm_version_table

applied_scripts = db.get_applied_scripts

script_files = Dir["#{schema_dir}/*.sql"]

# Do not run any script files that have been run.
(script_files - applied_scripts).each do |script|
  # Skip any files that does not start with a sequence of numbers.
  next unless File.basename(script) =~ /^\d+/

  puts "Running #{script}"
  db.apply_script script
end
