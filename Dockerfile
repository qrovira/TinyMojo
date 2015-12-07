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
    DBD::mysql \
    IO::Socket::SSL \
    Email::Valid \
    Mojolicious::Plugin::I18N

RUN cpanm \
    https://github.com/qrovira/BootstrapHelpers.git \
    https://github.com/qrovira/devpanels.git
    

WORKDIR /usr/src/tinymojo

EXPOSE 8080
EXPOSE 8081

CMD [ "hypnotoad", "script/tiny_mojo", "-f" ]

COPY . /usr/src/tinymojo
