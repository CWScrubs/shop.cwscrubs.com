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
LOG="${DIR}/error.log"
CLI_SCRIPT="${BIN}/vars"
RUN_SCRIPT="${BIN}/run-ubuntu.sh"
SERVICE_RUN_SCRIPT="${BIN}/run-ubuntu-service.sh"
NGINX_CONF="${ETC}/nginx/nginx.conf"
PHP_INI="${ETC}/php/php.ini"
PHP_FPM_CONF="${ETC}/php/php-fpm.conf"

printf "\n"
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
printf "\n"
printf "Is this correct (y or n): "
read -n 1 CORRECT
printf "\n"

if  [ "${CORRECT}" == "y" ]; then

    if [ -f ${RUN_SCRIPT} ]; then
       rm ${RUN_SCRIPT}
    fi
    cp ${BIN}/run.sh.dist ${RUN_SCRIPT}

    sed -i -e s/__SITE_NAME__/"${SITE_NAME}"/g ${RUN_SCRIPT}
    sed -i -e s/__PORT__/"${PORT}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_HOST__/"${WP_HOST}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_NAME__/"${WP_NAME}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_USER__/"${WP_USER}"/g ${RUN_SCRIPT}
    sed -i -e s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${RUN_SCRIPT}
    sed -i -e s/__FORCE_SSL__/"${FORCE_SSL}"/g ${RUN_SCRIPT}
    chmod +x ${RUN_SCRIPT}

    if [ -f ${CLI_SCRIPT} ]; then
       rm ${CLI_SCRIPT}
    fi
    cp ${BIN}/vars.dist ${CLI_SCRIPT}

    sed -i -e s/__SITE_DOMAINS__/"${SITE_DOMAINS}"/g ${CLI_SCRIPT}
    sed -i -e s/__PORT__/"${PORT}"/g ${CLI_SCRIPT}
    sed -i -e "s __DATE_TIMEZONE__ $DATE_TIMEZONE g" ${CLI_SCRIPT}
    sed -i -e s/__SITE_NAME__/"${SITE_NAME}"/g ${CLI_SCRIPT}
    sed -i -e s/__PORT__/"${PORT}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_HOST__/"${WP_HOST}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_NAME__/"${WP_NAME}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_USER__/"${WP_USER}"/g ${CLI_SCRIPT}
    sed -i -e s/__WP_PASSWORD__/"${WP_PASSWORD}"/g ${CLI_SCRIPT}
    sed -i -e s/__FORCE_SSL__/"${FORCE_SSL}"/g ${CLI_SCRIPT}
    chmod +x ${CLI_SCRIPT}

    if [ -f ${NGINX_CONF} ]; then
       rm ${NGINX_CONF}
    fi
    cp ${ETC}/nginx/nginx.dist.conf ${NGINX_CONF}

    sed -i -e "s __LOG__ $LOG g" ${NGINX_CONF}
    sed -i -e s/__SITE_DOMAINS__/"${SITE_DOMAINS}"/g ${NGINX_CONF}
    sed -i -e s/__PORT__/"${PORT}"/g ${NGINX_CONF}

    if [ -f ${PHP_INI} ]; then
       rm ${PHP_INI}
    fi
    cp ${ETC}/php/php.template.ini ${PHP_INI}

    sed -i -e "s __LOG__ $LOG g" ${PHP_INI}
    sed -i -e "s __DATE_TIMEZONE__ $DATE_TIMEZONE g" ${PHP_INI}
    sed -i -e "s __TMP__ $TMP g" ${PHP_INI}
    sed -i -e s/__OPCACHE_VALIDATE_TIMESTAMPS__/"${OPCACHE_VALIDATE_TIMESTAMPS}"/g ${PHP_INI}

    if [ -f ${PHP_FPM_CONF} ]; then
       rm ${PHP_FPM_CONF}
    fi
    cp ${ETC}/php/php-fpm.template.conf ${PHP_FPM_CONF}
    sed -i -e "s __LOG__ $LOG g" ${PHP_FPM_CONF}
    sed -i -e "s __TMP__ $TMP g" ${PHP_FPM_CONF}

printf "\n"
printf "\n"
printf "\n"
printf "================================================================\n"
printf "\n"
printf "Your run script has been created at: \n"
printf "${RUN_SCRIPT}\n"
printf "\n"
else
printf "Please run this script again to enter the correct configuration. \n"
printf "\n"
printf "================================================================\n"
exit 1
fi

if [ -f ${SERVICE_RUN_SCRIPT} ]; then
    rm ${SERVICE_RUN_SCRIPT}
fi
cp ${RUN_SCRIPT} ${SERVICE_RUN_SCRIPT}
sed -i -e s/"supervisord.conf"/"supervisord.service.conf"/g ${SERVICE_RUN_SCRIPT}

VERSION=$(lsb_release -r | cut -d : -f 2- | sed 's/^[ \t]*//;s/[ \t]*$//')
MAJOR_VERSION=$(echo "${VERSION%%.*}")
if [ "${MAJOR_VERSION}" -gt "14" ]; then
    printf "version: ${VERSION} detected. Creating systemd job...\n"
    SYSTEMD_CONF_FILE="${ETC}/${SITE_NAME}.service"
    if [ -f ${SYSTEMD_CONF_FILE} ]; then
       rm ${SYSTEMD_CONF_FILE}
    fi

    printf "[Unit]\n" >> ${SYSTEMD_CONF_FILE}
    printf "Description=Service for running the ${SITE_NAME} website\n" >> ${SYSTEMD_CONF_FILE}
    printf "After=network.target\n" >> ${SYSTEMD_CONF_FILE}
    printf "\n" >> ${SYSTEMD_CONF_FILE}
    printf "[Service]\n" >> ${SYSTEMD_CONF_FILE}
    printf "Type=forking\n" >> ${SYSTEMD_CONF_FILE}
    printf "WorkingDirectory=${DIR}\n" >> ${SYSTEMD_CONF_FILE}
    printf "ExecStop=${BIN}/stop.sh\n" >> ${SYSTEMD_CONF_FILE}
    printf "ExecStart=${SERVICE_RUN_SCRIPT}\n" >> ${SYSTEMD_CONF_FILE}
    printf "KillMode=process\n" >> ${SYSTEMD_CONF_FILE}
    printf "\n" >> ${SYSTEMD_CONF_FILE}
    printf "[Install]\n" >> ${SYSTEMD_CONF_FILE}
    printf "WantedBy=multi-user.target\n" >> ${SYSTEMD_CONF_FILE}
    printf "\n"
    printf "A systemd configuration has been created\n"
    printf "To enable the website as a service run the following:\n"
    printf "sudo systemctl enable ${SYSTEMD_CONF_FILE}\n"
    printf "\n";
    printf "Then you can start the service manually like this:\n"
    printf "sudo systemctl start ${SITE_NAME}\n"
    printf "================================================================\n"
else
    printf "version: ${VERSION} detected. Creating upstart job...\n"
    UPSTART_CONF_FILE="${ETC}/${SITE_NAME}.conf"
    if [ -f ${UPSTART_CONF_FILE} ]; then
       rm ${UPSTART_CONF_FILE}
    fi
    printf "# ${SITE_NAME} service\n" >> ${UPSTART_CONF_FILE}
    printf "\n"  >> ${UPSTART_CONF_FILE}
    printf "description \"Service for running the ${SITE_NAME} website\"\n" >> ${UPSTART_CONF_FILE}
    printf "author \"Jesse Greathouse <jesse@greathouse.technology>\" \n" >> ${UPSTART_CONF_FILE}
    printf "\n" >> ${UPSTART_CONF_FILE}
    printf "chdir ${DIR}\n" >> ${UPSTART_CONF_FILE}
    printf "\n" >> ${UPSTART_CONF_FILE}
    printf "start on runlevel [2345]\n" >> ${UPSTART_CONF_FILE}
    printf "stop on runlevel [016]\n" >> ${UPSTART_CONF_FILE}
    printf "\n" >> ${UPSTART_CONF_FILE}
    printf "exec ${SERVICE_RUN_SCRIPT}\n" >> ${UPSTART_CONF_FILE}
    printf "An upstart configuration has been created. To run the website as a service copy and paste this line:\n"
    printf "sudo cp ${UPSTART_CONF_FILE} /etc/init/\n"
    printf "\n"
    printf "Then, you can start the service manually like this::\n"
    printf "sudo service ${SITE_NAME} start\n"
    printf "================================================================\n"
fi
