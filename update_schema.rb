#!/usr/bin/env ruby

require 'yaml'
require 'pry'
require 'pry-debugger'
require 'mysql2'
require 'optparse'

class DatabaseClient
  def confirm_version_table
   confirm_database_selected

   execute_sql(self.class::CREATE_VERSION_TABLE)
  end

  # Typically we'll be in the context of a database, but when setting up a database, then none will be selected or even there.
  # In that case we'll record script files in a update_schema_db database.
  def confirm_database_selected
    unless get_scalar("select database()")
      execute_sql "create database if not exists update_schema_db"
      execute_sql "use update_schema_db"
    end
  end

  def get_applied_scripts
    get_single_column self.class::GET_APPLIED_SCRIPTS
  end

  def apply_script sql_script_file, opts
    sql_text = File.read(sql_script_file)
    sql_chunks = sql_text.split(/;/)
    begin_trans
    sql_chunks.each do |hunk|
      # Skip if the hunk is just whitespace.
      next if hunk =~ /\A\s*\Z/
      execute_sql hunk
    end
    record_script_applied sql_script_file if opts[:record]
    commit_trans
    puts "Applied #{File.basename(sql_script_file)}."
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
  #
  # Returns a single value
  def get_scalar sql_text
    @client.query(sql_text, :as => :array).first[0]
  end

  def record_script_applied sql_file
    # Since mysql2 does not support parameterized queries, we're inlining the SQL statement.
    execute_sql "insert into schema_version (script_name, applied_timestamp) values ('#{sql_file}', NOW())"
  end
end

class UpdateSchemaBase
  def self.get_database_client config
    environment = ENV['APP_ENV'] || "development"

    unless File.exists? config
      puts "Could not find #{config}", USAGE
      exit 2
    end

    database_config = YAML.load_file(config)[environment]

    if ENV['DB_HOST']
      database_config.merge!({ "host" => ENV['DB_HOST']})
    end

    DatabaseClient.load(database_config)
  end
end

class RunOneFile < UpdateSchemaBase
  def self.run sql_file, opts
    config = File.basename(sql_file, ".sql")
    db = get_database_client File.join(File.dirname(sql_file), "#{config}.yml")

    db.confirm_version_table

    applied_scripts = db.get_applied_scripts

    db.apply_script(sql_file, opts) unless applied_scripts.include?(sql_file)
  end
end

class UpdateSchema < UpdateSchemaBase
  def self.run schema_dir, opts

    db = get_database_client "#{schema_dir}/database.yml"
    db.confirm_version_table

    applied_scripts = db.get_applied_scripts

    script_files = Dir["#{schema_dir}/*.sql"]

    # Do not run any script files that have been run.
    (script_files - applied_scripts).each do |script|
      # Skip any files that does not start with a sequence of numbers.
      next unless File.basename(script) =~ /^\d+/

      db.apply_script script, opts
    end
  end
end

USAGE=<<USAGE
usage: update_schema [-n] schema_dir
 Where schema_dir contains a database configuration file (database.yml) and SQL script files.
options:
  -n,--no-record Does not record the execution of the script file(s), useful when you want the script to be re-runnable.
USAGE

options = { :record => true }
OptionParser.new do |opts|
  opts.on("-n", "--no-record", "Do not record the script(s) applied") do |v|
    options[:record] = false
  end
end.parse!


first_arg = ARGV.pop
unless first_arg && (Dir.exists?(first_arg) || File.exists?(first_arg))
  puts USAGE
  exit 1
end

if File.file? first_arg
  RunOneFile.run first_arg, options
  exit
end

UpdateSchema.run first_arg.chomp('/'), options
