FROM perl:latest

RUN cpanm \
    Mojolicious \
    JSON::XS \
    Crypt::Skip32 \
    DBIx::Class \
    DBIx::Connector \
    String::Random \
    Crypt::Passwd::XS \
    DBIx::Class::EncodedColumn \
    Locale::Wolowitz \
    Mojolicious::Plugin::Wolowitz \
    Data::UUID::MT \
    DBD::mysql

RUN cpanm \
    https://github.com/qrovira/BootstrapHelpers.git \
    https://github.com/qrovira/devpanels.git
    

COPY . /usr/src/tinymojo

WORKDIR /usr/src/tinymojo

EXPOSE 8080

CMD [ "hypnotoad", "script/app_tiny_mojo", "-f" ]
