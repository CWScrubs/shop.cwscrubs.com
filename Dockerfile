FROM alpine:3.8
MAINTAINER Jesse Greathouse <jesse@greathouse.technology>

ENV PATH /app/bin:$PATH

# Set the correct timezone in the container
# Analytics needs this to be central time for legacy purposes
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Get core utils
RUN apk add --no-cache \
    bash git wget curl autoconf nodejs openssh nasm dpkg-dev dpkg file  coreutils \
    libc-dev curl-dev libressl-dev libxml2-dev readline-dev ncurses-libs libedit-dev \
    pcre-dev icu-libs libxslt perl g++ gcc make ca-certificates glib pkgconf re2c \
    freetype libpng libjpeg-turbo libpng-dev libjpeg-turbo-dev freetype-dev libsodium-dev \
    zlib zlib-dev gmp-dev iso-codes python py-curl supervisor msmtp xz

# Add preliminary file structure
RUN mkdir /app
RUN mkdir /app/bin
RUN mkdir /app/etc
RUN mkdir /app/opt
RUN mkdir /app/tmp
RUN mkdir /app/tmp/session
RUN mkdir /app/var
RUN mkdir /app/var/cache
RUN mkdir /app/var/logs
RUN touch /app/var/logs/app.log
RUN touch /app/error.log
ADD opt /app/opt
ADD bin/install.sh /app/bin/install.sh

WORKDIR /app

# Run the install script
RUN bin/install.sh

# Remove all dependency tarballs
RUN rm -rf /app/opt/*tar.gz

# Install test runner
ADD phpunit-5.4.2.phar /app/phpunit-5.4.2.phar
RUN ln -s /app/phpunit-5.4.2.phar /app/bin/phpunit
ADD bin/run_tests.sh /app/bin/run_tests.sh
ADD phpunit.xml /app/phpunit.xml

# Build Vendors
ADD composer.phar /app/composer.phar
ADD composer.json /app/composer.json
ADD composer.lock /app/composer.lock
RUN php composer.phar install --no-interaction --no-scripts --no-autoloader

# Add wp-cli
ADD wp-cli.phar /app/wp-cli.phar

# Project files
ADD etc/ /app/etc
ADD web/ /app/web
ADD src/ /app/src

# Run post install hooks
RUN php composer.phar dump-autoload --optimize
RUN php composer.phar run-script post-install-cmd

# Expose ports
EXPOSE 3000

CMD ["/usr/bin/supervisord", "-c", "/app/etc/supervisor/conf.d/supervisord.conf"]