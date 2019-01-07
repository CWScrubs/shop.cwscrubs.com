#!/usr/bin/env bash

# resolve real path to script including symlinks or other hijinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET="$(readlink "$SOURCE")"
  if [[ ${TARGET} == /* ]]; then
    echo "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE="$TARGET"
  else
    BIN="$( dirname "$SOURCE" )"
    echo "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$BIN')"
    SOURCE="$BIN/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
USER="$( whoami )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"

#Install PHP
tar -xzf ${OPT}/php-*.tar.gz -C ${OPT}/

cd ${OPT}/php-*/
make clean
./buildconf --force

./configure --prefix=${OPT}/php \
            --with-config-file-path=${ETC}/php \
            --enable-opcache \
            --enable-fpm \
            --enable-mbstring \
            --enable-zip \
            --enable-bcmath \
            --enable-pcntl \
            --enable-ftp \
            --enable-exif \
            --enable-calendar \
            --enable-sysvmsg \
            --enable-sysvsem \
            --enable-sysvshm \
            --enable-soap \
            --enable-wddx \
            --enable-ipv6 \
            --with-mhash \
            --with-sodium=shared \
            --with-curl \
            --without-iconv \
            --with-libedit \
            --with-iconv \
            --with-gmp \
            --with-gd \
            --with-freetype-dir=/usr/include/ \
            --with-png-dir=/usr/include/ \
            --with-jpeg-dir=/usr/include/ \
            --with-zlib-dir=/usr/include/ \
            --enable-gd-native-ttf \
            --with-zlib \
            --with-openssl \
            --enable-mysqlnd \
            --with-mysqli=mysqlnd \
            --with-pdo-mysql=mysqlnd \
            --with-mysql-sock=/tmp/mysql.sock && \
make
make install
rm -rf ${OPT}/php-*/
ln -sf ${OPT}/php/bin/php ${BIN}/php
ln -sf ${OPT}/php/bin/phpize ${BIN}/phpize
ln -sf ${OPT}/php/bin/pecl ${BIN}/pecl
ln -sf ${OPT}/php/bin/pear ${BIN}/pear

# Compile and Install Openresty
tar -xzf ${OPT}/openresty-*.tar.gz -C ${OPT}/

cd ${OPT}/openresty-*/
./configure --with-cc-opt="-I/usr/local/include -I/usr/local/opt/openssl/include" \
            --with-ld-opt="-L/usr/local/lib -L/usr/local/opt/openssl/lib" \
            --prefix=${OPT}/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-http_iconv_module \
            --with-http_realip_module \
            -j2 && \
make
make install

cd ${DIR}
rm -rf ${OPT}/openresty-*/
ln -sf ${OPT}/openresty/nginx/sbin/nginx ${BIN}/nginx

