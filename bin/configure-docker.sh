#!/usr/bin/env bash

# This script will prompt the user to provide necessary strings
# to customize their run script

# resolve real path to script including symlinks or other hijinks
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  TARGET="$(readlink "$SOURCE")"
  if [[ ${TARGET} == /* ]]; then
    printf "SOURCE '$SOURCE' is an absolute symlink to '$TARGET'"
    SOURCE="$TARGET"
  else
    BIN="$( dirname "$SOURCE" )"
    printf "SOURCE '$SOURCE' is a relative symlink to '$TARGET' (relative to '$BIN')"
    SOURCE="$BIN/$TARGET" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  fi
done
RBIN="$( dirname "$SOURCE" )"
BIN="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
DIR="$( cd -P "$BIN/../" && pwd )"
ETC="$( cd -P "$DIR/etc" && pwd )"
TMP="$( cd -P "$DIR/tmp" && pwd )"
USER="$(whoami)"
LOG="/app/error.log"
DOCKER_TMP="/app/tmp"
CLI_SCRIPT="${BIN}/wp"
RUN_SCRIPT="${BIN}/run-docker.sh"
STOP_SCRIPT="${BIN}/stop-docker.sh"
NGINX_CONF="${ETC}/nginx/nginx.conf"
PHP_INI="${ETC}/php/php.ini"
PHP_FPM_CONF="${ETC}/php/php-fpm.conf"

printf "\n"
printf "\n"
printf "=================================================================\n"
printf "Hello, "${USER}".  This will create your site's run script\n"
printf "=================================================================\n"
printf "\n"
printf "Enter your name of your site [${USER}]: "
read SITE_NAME
if  [ "${SITE_NAME}" == "" ]; then
    SITE_NAME=${USER}
fi
printf "Enter the domains of your site [127.0.0.1 localhost]: "
read SITE_DOMAINS
if  [ "${SITE_DOMAINS}" == "" ]; then
    SITE_DOMAINS="127.0.0.1 localhost"
fi
printf "Enter your website port [3000]: "
read PORT
if  [ "${PORT}" == "" ]; then
    PORT="3000"
fi
printf "Enter your database host [192.168.0.1]: "
read WP_HOST
if  [ "${WP_HOST}" == "" ]; then
    WP_HOST="192.168.0.1"
fi
printf "Enter your database name [db_name]: "
read WP_NAME
if  [ "${WP_NAME}" == "" ]; then
    WP_NAME="db_name"
fi
printf "Enter your database user [db_user]: "
read WP_USER
if  [ "${WP_USER}" == "" ]; then
    WP_USER="db_user"
fi
printf "Enter your database password [db_password]: "
read WP_PASSWORD
if  [ "${WP_PASSWORD}" == "" ]; then
    WP_PASSWORD="db_password"
fi
printf "Force visitors to https? (y or n): "
read -n 1 FORCE_SSL
if  [ "${FORCE_SSL}" == "y" ]; then
    FORCE_SSL="true"
else
    FORCE_SSL="false"
fi
printf "\nDo you want the site to run on system reboot? (y or n): "
read -n 1 RESTART_POLICY
if  [ "${RESTART_POLICY}" == "n" ]; then
    RESTART_POLICY="no"
else
    RESTART_POLICY="unless-stopped"
fi
printf "\nOpcache Ignore File changes [code changes require reload]? (y or n): "
read -n 1 OPCACHE_IGNORE_TIMESTAMPS
if  [ "${OPCACHE_IGNORE_TIMESTAMPS}" == "y" ]; then
    OPCACHE_VALIDATE_TIMESTAMPS="0"
else
    OPCACHE_VALIDATE_TIMESTAMPS="1"
fi
printf "\nServer Timezone [America/Chicago]: "
read DATE_TIMEZONE
if  [ "${DATE_TIMEZONE}" == "" ]; then
    DATE_TIMEZONE="America/Chicago"
fi

printf "\n"
printf "You have entered the following configuration: \n"
printf "\n"
printf "Site Name: ${SITE_NAME} \n"
printf "Site Domains: ${SITE_DOMAINS} \n"
printf "Web Port: ${PORT} \n"
printf "Database Host: ${WP_HOST} \n"
printf "Database Name: ${WP_NAME} \n"
printf "Database User: ${WP_USER} \n"
printf "Database Password: ${WP_PASSWORD} \n"
printf "Force Https: ${FORCE_SSL} \n"
printf "Run On Reboot: ${RESTART_POLICY} \n"
printf "Opcache Ignore File Changes: ${OPCACHE_IGNORE_TIMESTAMPS} \n"
printf "Server Timezone: ${DATE_TIMEZONE} \n"
printf "\n"
printf "Is this correct (y or n): "
read -n 1 CORRECT
printf "\n"

if  [ "${CORRECT}" == "y" ]; then

    if [ -f ${RUN_SCRIPT} ]; then
       rm ${RUN_SCRIPT}
    fi
    cp ${BIN}/run-docker.sh.dist ${RUN_SCRIPT}

    sed -i -e s/__SITE_NAME__/"${SITE_NAME}"/g ${RUN_SCRIPT}
    sed -i -e s/__PORT__/"${PORT}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_HOST__/"${WP_HOST}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_NAME__/"${WP_NAME}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_USER__/"${WP_USER}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${RUN_SCRIPT}
    sed -i -e s/__FORCE_SSL__/"${FORCE_SSL}"/g ${RUN_SCRIPT}
    sed -i -e s/__RESTART_POLICY__/"${RESTART_POLICY}"/g ${RUN_SCRIPT}
    chmod +x ${RUN_SCRIPT}

    if [ -f ${CLI_SCRIPT} ]; then
       rm ${CLI_SCRIPT}
    fi
    cp ${BIN}/wp.dist ${CLI_SCRIPT}

    sed -i -e s/__SITE_NAME__/"${SITE_NAME}"/g ${CLI_SCRIPT}
    sed -i -e s/__PORT__/"${PORT}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_HOST__/"${WP_HOST}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_NAME__/"${WP_NAME}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_USER__/"${WP_USER}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${CLI_SCRIPT}
    sed -i -e s/__FORCE_SSL__/"${FORCE_SSL}"/g ${CLI_SCRIPT}
    sed -i -e s/__RESTART_POLICY__/"${RESTART_POLICY}"/g ${CLI_SCRIPT}
    chmod +x ${CLI_SCRIPT}

    if [ -f ${NGINX_CONF} ]; then
       rm ${NGINX_CONF}
    fi
    cp ${ETC}/nginx/nginx.dist.conf ${NGINX_CONF}

    sed -i -e "s __LOG__ $LOG g" ${NGINX_CONF}
    sed -i -e s/__SITE_DOMAINS__/"${SITE_DOMAINS}"/g ${NGINX_CONF}
    sed -i -e s/__PORT__/"3000"/g ${NGINX_CONF}

    if [ -f ${PHP_INI} ]; then
       rm ${PHP_INI}
    fi
    cp ${ETC}/php/php.template.ini ${PHP_INI}

    sed -i -e "s __LOG__ $LOG g" ${PHP_INI}
    sed -i -e "s __DATE_TIMEZONE__ $DATE_TIMEZONE g" ${PHP_INI}
    sed -i -e "s __TMP__ $DOCKER_TMP g" ${PHP_INI}
    sed -i -e s/__OPCACHE_VALIDATE_TIMESTAMPS__/"${OPCACHE_VALIDATE_TIMESTAMPS}"/g ${PHP_INI}

    if [ -f ${PHP_FPM_CONF} ]; then
       rm ${PHP_FPM_CONF}
    fi
    cp ${ETC}/php/php-fpm.template.conf ${PHP_FPM_CONF}
    sed -i -e "s __LOG__ $LOG g" ${PHP_FPM_CONF}
    sed -i -e "s __TMP__ $DOCKER_TMP g" ${PHP_FPM_CONF}

    if [ -f ${STOP_SCRIPT} ]; then
       rm ${STOP_SCRIPT}
    fi
    cp ${BIN}/stop-docker.sh.dist ${STOP_SCRIPT}

    sed -i -e s/__CONTAINER_NAME__/"${SITE_NAME}"/g ${STOP_SCRIPT}

    printf "Your run script has been created\n"
    printf "Run your sever by using: ${RUN_SCRIPT}\n"
    exit 0
else
    printf "Please run this script again to enter the correct configuration. \n"
    exit 1
fi
