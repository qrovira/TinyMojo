# NAME

TinyMojo - URL shortener application

[![Build Status](https://travis-ci.org/qrovira/TinyMojo.svg?branch=master)](https://travis-ci.org/qrovira/TinyMojo)

# SYNOPSIS

Small proof of concept [Mojolicious](https://metacpan.org/pod/Mojolicious) app for URL shortening.

The approach taken for the shortening relies entirely on the auto\_increment
primary key on the database backend, which avoids all kinds of messy queries
during shortening or lookup.

It also avoids sequentiality on the generated URLs by using [Crypt::Skip32](https://metacpan.org/pod/Crypt::Skip32).

## DOCKER DEPLOY

Docker files are provided to bootstrap a working Tinymojo, including an image for
the webapp that will run on hypnotoad, and a separate instance for the database,
initialized with empty tables and a _admin_/_password_ user.

You can manage it via `docker-compose` (eg. `docker-compose up -d`).

Remember to update all configuration, session, datbase and user secrets!

## CONFIGURATION

All configuration is done through the default [Mojolicious::Plugin::Config](https://metacpan.org/pod/Mojolicious::Plugin::Config) plugin,
which you can see on the `tiny_mojo.conf` file.

There you can set the encryption key (10 bytes, 20 hex chars), along with the database settings.

### Example configuration

    {
        # Key size for Skip32 or Skipjack is 10 bytes
        crypt_key => '1337b33f0000f33b7331',
    
        # Some site vars
        allow_anonymous_shorten => 1,
        track_visits => 1,
    
        # Database configuration
        database => {
            dsn      => "dbi:mysql:dbname=tinymojo;host=mysql",
            username => "tinymojo",
            password => "tinymojo",
        },
    
        # Session encryption secret
        secrets => [
            'heregoesyoursecret'
        ],
    
        # I18N
        i18n => {
            default => "en",
            support_session => "lang",
        },
    
        # eMail config
        mail => {
            from => 'tinymojo@localhost',
            # bcc, reply_to, etc.
        },
    
        # hypnotoad configuration
        hypnotoad => {
            proxy => 1,
            listen => [
                "http://*:8080",
                "https://*:8081",
            ],
        },
    };

# SHORTENING METHOD

The shortening works like follows:

- Insert to database, and retrieve the auto\_increment $id
- Encrypt the id using [Crypt::Skip32](https://metacpan.org/pod/Crypt::Skip32)

    This assumes 32 bit ints as IDs, but you can switch to 64 bits and [Crypt::Skipjack](https://metacpan.org/pod/Crypt::Skipjack).

- Apply a naive base change using a hardcoded dictionary of URL-friendly characters

The lookup of shortened URLs is prety straight forward given the above method.

# DATABASE

The database only requires two tables: _url_ and _user_, and optionally _redirect_ if
you plan to track short url visits.

### URL table

    CREATE TABLE url (
      id int auto_increment primary key,
      longurl varchar(4096),
      user_id int not null default 0
    );

### User table

    CREATE TABLE `user` (
      id int auto_increment primary key,
      login varchar(255) not null,
      email varchar(100) not null,
      email_verified tinyint(1) default 0,
      password varchar(512),
      admin bool not null default 0,
    );

### Tracking table

    CREATE TABLE `redirect` (
      id int auto_increment primary key,
      url_id int not null,
      time timestamp not null default current_timestamp,
      visitor_ip varchar(39) not null,
      visitor_forwarded_for varchar(255) default null,
      visitor_uuid varchar(100) default null,
      visitor_ua varchar(1024) default null,
    )

# CAVEATS

All of them. This is just a proof of concept :)

Do not use on the wild under any circumstances.. it does not check pretty much anything.
