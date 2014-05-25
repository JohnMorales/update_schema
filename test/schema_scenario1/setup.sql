DROP DATABASE IF EXISTS update_schema_scenario1;

CREATE DATABASE update_schema_scenario1;

GRANT ALL PRIVILEGES ON update_schema_scenario1.* TO 'test_user'@'%' identified by 'password2';

FLUSH PRIVILEGES;
