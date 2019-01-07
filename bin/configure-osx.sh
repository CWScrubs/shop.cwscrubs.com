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
CLI_SCRIPT="${BIN}/vars"
LOG="${DIR}/error.log"
RUN_SCRIPT="${BIN}/run-osx.sh"
SERVICE_RUN_SCRIPT="${BIN}/run-osx-service.sh"
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
printf "Enter the domains of your site delimited by a single space [127.0.0.1]: "
read SITE_DOMAINS
if  [ "${SITE_DOMAINS}" == "" ]; then
    SITE_DOMAINS="127.0.0.1"
fi
printf "Enter your website port [80]: "
read PORT
if  [ "${PORT}" == "" ]; then
    PORT="80"
fi
printf "Enter your database host [127.0.0.1]: "
read WP_HOST
if  [ "${WP_HOST}" == "" ]; then
    WP_HOST="127.0.0.1"
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
printf "Opcache Ignore File Changes: ${OPCACHE_IGNORE_TIMESTAMPS} \n"
printf "Server Timezone: ${DATE_TIMEZONE} \n"
printf "Escaped Timezone: ${ESCAPED_DATE_TIMEZONE}\n"
printf "\n"
printf "Is this correct (y or n): "
read -n 1 CORRECT
printf "\n"

if  [ "${CORRECT}" == "y" ]; then

    if [ -f ${RUN_SCRIPT} ]; then
       rm ${RUN_SCRIPT}
    fi
    cp ${BIN}/run.sh.dist ${RUN_SCRIPT}

    sed -i '' '1 a\
        PATH=/usr/local/bin:$PATH' ${RUN_SCRIPT}
    sed -i '' s/__SITE_NAME__/"${SITE_NAME}"/g ${RUN_SCRIPT}
    sed -i '' s/__PORT__/"${PORT}"/g ${RUN_SCRIPT}
    sed -i '' s/__WP_HOST__/"${WP_HOST}"/g ${RUN_SCRIPT}
    sed -i '' s/__WP_NAME__/"${WP_NAME}"/g ${RUN_SCRIPT}
    sed -i '' s/__WP_USER__/"${WP_USER}"/g ${RUN_SCRIPT}
    sed -i '' s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${RUN_SCRIPT}
    sed -i '' s/__FORCE_SSL__/"${FORCE_SSL}"/g ${RUN_SCRIPT}
    chmod +x ${RUN_SCRIPT}

    if [ -f ${CLI_SCRIPT} ]; then
       rm ${CLI_SCRIPT}
    fi
    cp ${BIN}/vars.dist ${CLI_SCRIPT}

    
    sed -i '' '1 a\
        PATH=/usr/local/bin:$PATH' ${CLI_SCRIPT}
    sed -i '' s/__SITE_DOMAINS__/"${SITE_DOMAINS}"/g ${CLI_SCRIPT}
    sed -i '' s/__PORT__/"${PORT}"/g ${CLI_SCRIPT}
    sed -i '' "s __DATE_TIMEZONE__ $DATE_TIMEZONE g" ${CLI_SCRIPT}
    sed -i '' s/__SITE_NAME__/"${SITE_NAME}"/g ${CLI_SCRIPT}
    sed -i '' s/__PORT__/"${PORT}"/g ${CLI_SCRIPT}
    sed -i '' s/__WP_HOST__/"${WP_HOST}"/g ${CLI_SCRIPT}
    sed -i '' s/__WP_NAME__/"${WP_NAME}"/g ${CLI_SCRIPT}
    sed -i '' s/__WP_USER__/"${WP_USER}"/g ${CLI_SCRIPT}
    sed -i '' s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${CLI_SCRIPT}
    sed -i '' s/__FORCE_SSL__/"${FORCE_SSL}"/g ${CLI_SCRIPT}
    chmod +x ${CLI_SCRIPT}

    if [ -f ${NGINX_CONF} ]; then
       rm ${NGINX_CONF}
    fi
    cp ${ETC}/nginx/nginx.dist.conf ${NGINX_CONF}

    sed -i '' "s __LOG__ $LOG g" ${NGINX_CONF}
    sed -i '' s/__SITE_DOMAINS__/"${SITE_DOMAINS}"/g ${NGINX_CONF}
    sed -i '' s/__PORT__/"${PORT}"/g ${NGINX_CONF}

    if [ -f ${PHP_INI} ]; then
       rm ${PHP_INI}
    fi
    cp ${ETC}/php/php.template.ini ${PHP_INI}

    sed -i '' "s __LOG__ $LOG g" ${PHP_INI}
    sed -i '' "s __DATE_TIMEZONE__ $DATE_TIMEZONE g" ${PHP_INI}
    sed -i '' "s __TMP__ $TMP g" ${PHP_INI}
    sed -i '' s/__OPCACHE_VALIDATE_TIMESTAMPS__/"${OPCACHE_VALIDATE_TIMESTAMPS}"/g ${PHP_INI}

    if [ -f ${PHP_FPM_CONF} ]; then
       rm ${PHP_FPM_CONF}
    fi
    cp ${ETC}/php/php-fpm.template.conf ${PHP_FPM_CONF}
    sed -i '' "s __LOG__ $LOG g" ${PHP_FPM_CONF}
    sed -i '' "s __TMP__ $TMP g" ${PHP_FPM_CONF}

    printf "\n"
    printf "\n"
    printf "\n"
    printf "================================================================\n"
    printf "\n"
    printf "Your run script has been created. \n"
    printf "To run your website only once paste this script into the console:  \n"
    printf "${RUN_SCRIPT}\n"
    printf "\n"
else
    printf "Please run this script again to enter the correct configuration. \n"
    printf "\n"
    printf "================================================================\n"
    exit 1
fi

printf "Creating startup script...\n"

LAUNCHD_CONF="${ETC}/com.greathouse.technology.${SITE_NAME}.plist"

if [ -f ${LAUNCHD_CONF} ]; then
   rm ${LAUNCHD_CONF}
fi

cp "${ETC}/com.greathouse.technology.template.plist" ${LAUNCHD_CONF}

sed -i '' "s __LABEL__ $SITE_NAME " ${LAUNCHD_CONF}
sed -i '' "s __RUN_SCRIPT__ $RUN_SCRIPT " ${LAUNCHD_CONF}
sed -i '' "s __ERROR_PATH__ $DIR/error.log " ${LAUNCHD_CONF}
sed -i '' "s __STANDARD_OUT_PATH__ $DIR/supervisord.log " ${LAUNCHD_CONF}
sed -i '' "s __WORKING_DIRECTORY__ $DIR " ${LAUNCHD_CONF}

printf "To run the website when OSX boots, paste this into the console: \n"
printf "sudo cp -f ${LAUNCHD_CONF} /Library/LaunchDaemons\n"
printf "\n";
printf "================================================================\n"