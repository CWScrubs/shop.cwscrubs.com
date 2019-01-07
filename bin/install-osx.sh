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
GROUP="$( users )"
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
OPT="$( cd -P "$DIR/opt" && pwd )"
SRC="$( cd -P "$DIR/src" && pwd )"
MAGE_ROOT="$( cd -P "$DIR/web" && pwd )"
MAGE_BIN="$( cd -P "$MAGE_ROOT/bin" && pwd )"
PUBLIC="$( cd -P "$DIR/web" && pwd )"
YACC="$( brew --prefix bison )/bin/bison"

chmod 755 ${DIR}/..

#install dependencies
# brew upgrade
# brew install curl --with-libssh2 --with-openssl
# brew install intltool icu4c autoconf automake gmp bison@2.7 gd freetype t1lib gettext zlib mcrypt sendemail gmp pcre supervisord

# pip install supervisor

tar -xvf ${OPT}/php-*.tar.gz -C ${OPT}/

cd ${OPT}/php-*/

./buildconf --force
env YACC=`brew --prefix bison27`/bin/bison ./configure \
    --prefix=${OPT}/php \
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
    --enable-intl \
    --with-curl=`brew --prefix curl` \
    --with-iconv \
    --with-gmp=`brew --prefix gmp` \
    --with-gd \
    --with-freetype-dir=`brew --prefix freetype` \
    --with-jpeg-dir=`brew --prefix gd` \
    --with-png-dir=`brew --prefix gd` \
    --with-t1lib=`brew --prefix t1lib` \
    --enable-gd-native-ttf \
    --enable-gd-jis-conv \
    --with-openssl=`brew --prefix openssl` \
    --enable-mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-mysql-sock=/tmp/mysql.sock \
    --with-gettext=`brew --prefix gettext` \
    --with-zlib \
    --with-bz2 \
    --with-icu-dir=`brew --prefix icu4c` \
    --with-xsl \
    --with-mcrypt=`brew --prefix mcrypt`
make -j `sysctl -n hw.logicalcpu_max`
make install

rm -rf ${OPT}/php-*/

tar -xvf ${OPT}/openresty-*.tar.gz -C ${OPT}/

cd ${OPT}/openresty-*/
./configure --with-cc-opt="-I/usr/local/include -I/usr/local/opt/openssl/include" \
            --with-ld-opt="-L/usr/local/lib -L/usr/local/opt/openssl/lib" \
            --prefix=${OPT}/openresty \
            --with-pcre-jit \
            --with-ipv6 \
            --with-http_iconv_module \
            -j2 && \
make
make install

cd ${DIR}
rm -rf ${OPT}/openresty-*/

${BIN}/configure-osx.sh

${BIN}/install-magento.sh
