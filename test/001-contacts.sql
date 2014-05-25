DROP TABLE IF EXISTS Contacts;

CREATE TABLE Contacts(
contact_id int UNSIGNED NOT NULL AUTO_INCREMENT ,
name VARCHAR( 100 ) NOT NULL ,
email VARCHAR( 50 ) NOT NULL ,
subject VARCHAR( 100 ),
website VARCHAR( 100 ),
message VARCHAR( 4000 ),
createdAt DATETIME NOT NULL ,
updatedAt DATETIME NOT NULL ,
PRIMARY KEY ( contact_id )
)
