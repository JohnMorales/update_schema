Update Schema
=============

Migrations inspired simple ruby script to upgrade the database schema and keep
track of the latest applied version with minimal dependencies.

##Problem
I like the way rails handled database migrations, but as a polyglot I'm not
always working on a rails project.  I don't want to relearn how to solve the
problem of keeping my database schema up to date. I would like a tool that
works consistently no matter what framework, database or language I'm using.


##Solution
The goal is to create some tests of how I expect the tool to behave. And
hopefully the community could fork and develop their own tool for the language
and framework of their choice. The idea is that if we solve this problem with
the same pattern consistently for every language, then it makes developing in
multiple languages that much easier.

I'm writing the first draft in ruby and it's loosely based after rails
active_record migrations. There are no dependencies on active record or rails.
Instead reducing the dependencies as much as possible, there is a pattern to
support multiple database dialects, but the migration files are expected to be
specific to that dialect.  The other option the user can decide to make their
script files use only SQL spec statements that will work for every dialect they
are targeting.

##Setup
The default execution assumes that the database is already setup. Therefore
the main usage purposely does not try to setup the initial database and blindly
assumes that the user account and database is already setup.  It will ignore a
setup.sql script that could be used to manually create the database and user
for that initial environment creation. In fact it will ignore any script that
does not start with a number series.

That said if call it with a single argument that is a sql script, it will
assume that you want to execute an adhoc script, it will look for a database
configuration file of the same name to be used to connect to the database. This
could be used to to create the initial database and user. It will record the
execution of this script in the default database (update_schema_db) if one is
not assigned in the configuration.


##Running tests

Simply start up mysql if you don't already have one running and you have docker
installed you can run this:
docker run -d -p 3306:3306 tumtum/mysql

The tests assume that you have a admin user that create new users and databases
called test_admin, password: password1
  `GRANT ALL PRIVILEGES on *.* to test_admin@'%' identified by 'password1' WITH GRANT OPTION; flush privileges;`

Then set the DB_HOST to a value specific to your setup and then run `rake test`:

`DB_HOST=127.0.0.1 rake test`
