
CREATE TABLE url (
  id int auto_increment primary key,
  longurl varchar(4096),
  user_id int not null default 0
);

CREATE TABLE `user` (
  id int auto_increment primary key,
  login varchar(255) not null,
  email varchar(100) not null,
  password varchar(512),
  admin bool not null default 0
);

INSERT INTO user (login,password,admin) VALUES
("admin", CONCAT(SHA2(CONCAT("password","BADSALTBADSALT12"),512), "BADSALTBADSALT12"), 1);

CREATE TABLE `redirect` (
  id int auto_increment primary key,
  url_id int not null,
  time timestamp not null default current_timestamp,
  visitor_ip varchar(39) not null,
  visitor_forwarded_for varchar(255) default null,
  visitor_uuid varchar(100) default null,
  visitor_ua varchar(1024) default null
)

