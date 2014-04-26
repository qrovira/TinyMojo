# NAME

App::TinyMojo - URL shortener application

# SYNOPSIS

Small proof of concept [Mojolicious](https://metacpan.org/pod/Mojolicious) app for URL shortening.

The approach taken for the shortening relies entirely on the auto\_increment
primary key on the database backend, which avoids all kinds of messy queries
during shortening or lookup.

It also avoids sequentiality on the generated URLs by using [Crypt::Skip32](https://metacpan.org/pod/Crypt::Skip32).

## CONFIGURATION

All configuration is done through the default [Mojolicious::Plugin::Config](https://metacpan.org/pod/Mojolicious::Plugin::Config) plugin,
which you can see on the `app-tiny_mojo.conf` file.

There you can set the encryption key (10 bytes), along with the database settings.

### Example configuration

    {
        # Database configuration
        database => {
            dsn      => "dbi:mysql:dbname=tinymojo",
            username => "tinymojo",
            password => "tinymojo",
        },

        # Session encryption secret
        secrets => [
            'heregoesyoursecret'
        ],

        # Block size for Skip32 or Skipjack is 10 bytes
        crypt_key => '1234567890',
        
        # Some site vars
        language => 'en',
        site_name => 'TinyMojo',
        site_mission => 'Short URLs made simple.',
    };

# DATABASE

The database only requires two tables: for _url_s and _user_s.

### URL table example (MySQL)

    CREATE TABLE url (
      id int auto_increment primary key,
      longurl varchar(4096),
      user_id int not null default 0
    );

    CREATE TABLE `user` (
      id int auto_increment primary key,
      login varchar(255) not null,
      password varchar(512),
      admin bool not null default 0,
    );

# SHORTENING METHOD

The shortening works like follows:

- 1. Insert to database, and retrieve the auto\_increment $id
- 2. Encrypt the id using [Crypt::Skip32](https://metacpan.org/pod/Crypt::Skip32)

    This assumes 32 bit ints as IDs, but you can switch to 64 bits and [Crypt::Skipjack](https://metacpan.org/pod/Crypt::Skipjack).

- 3. Apply a naive base change using a hardcoded dictionary of URL-friendly characters

The lookup of shortened URLs is prety straight forward given the above method.

# CAVEATS

All of them. This is just a proof of concept :)

Do not use on the wild under any circumstances.. it does not check pretty much anything.
