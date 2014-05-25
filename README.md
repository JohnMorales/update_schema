Update Schema
=============

Simple ruby script to upgrade the database schema and keep track of the latest applied version.

##Setup
The tool purposely does not try to setup the initial database and blindly assume that the user account and
database is already setup. It will ignore a setup.sql script that could be used to manually create the database
and user for that initial environment creation. In fact it will ignore any script that does not start with a number series.
