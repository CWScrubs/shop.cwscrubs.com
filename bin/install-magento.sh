#!/usr/bin/env bash

# function for resolving the default base url
function resolve_default_base_url()
{
    local  __domain=$1
    local  __port=$2
    local  __force_ssl=$3
    DEFAULT_BASE_URL="127.0.0.1"

    if [ ! -z $__domain ]; then
        DEFAULT_BASE_URL=${__domain}
    fi

    if [ ! -z $__port ]; then
        DEFAULT_BASE_URL="${DEFAULT_BASE_URL}:${__port}"
    fi

    if  [ "${__force_ssl}" == "true" ]; then
        DEFAULT_BASE_URL="https://${DEFAULT_BASE_URL}/"
    else
        DEFAULT_BASE_URL="http://${DEFAULT_BASE_URL}/"
    fi
}

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
HERE="$(pwd)"

source ${BIN}/vars

# Run the function to determine the default base url
resolve_default_base_url $SITE_DOMAINS $PORT $FORCE_SSL

# Run the composer install
cd $MAGE_ROOT/
$OPT/php/bin/php $DIR/composer.phar install
cd $HERE

printf "\n"
printf "\n"
printf "=================================================================\n"
printf "Hello, "${USER}".  This will install Magento\n"
printf "=================================================================\n"
printf "\n"
printf "Enter your base URL [${DEFAULT_BASE_URL}]: "
read BASE_URL
if  [ "${BASE_URL}" == "" ]; then
    BASE_URL=${DEFAULT_BASE_URL}
fi
printf "Enter the Admin First Name [Magento]: "
read ADMIN_FIRSTNAME
if  [ "${ADMIN_FIRSTNAME}" == "" ]; then
    ADMIN_FIRSTNAME="Magento"
fi
printf "Enter the Admin Last Name [Admin]: "
read ADMIN_LASTNAME
if  [ "${ADMIN_LASTNAME}" == "" ]; then
    ADMIN_LASTNAME="Admin"
fi
printf "Enter the Admin Email (*required): "
read ADMIN_EMAIL
if  [ "${ADMIN_EMAIL}" == "" ]; then
    printf "An Email Address for the administrator is required for setup. \n"
    printf "Please run the magento-install.sh script again and enter the correct configuration. \n"
    printf "\n"
    printf "================================================================\n"
    exit 1
fi
printf "Enter your admin user [admin]: "
read ADMIN_USER
if  [ "${ADMIN_USER}" == "" ]; then
    ADMIN_USER="admin"
fi
printf "Enter your admin password (*required): "
read ADMIN_PASSWORD
if  [ "${ADMIN_PASSWORD}" == "" ]; then
    printf "A password for the admin user is required for setup. \n"
    printf "Please run the magento-install.sh script again and enter the correct configuration. \n"
    printf "\n"
    printf "================================================================\n"
    exit 1
fi
printf "Enter the language [en_US]: "
read LANGUAGE
if  [ "${LANGUAGE}" == "" ]; then
    LANGUAGE="en_US"
fi
printf "Enter the currency [USD]: "
read CURRENCY
if  [ "${CURRENCY}" == "" ]; then
    CURRENCY="USD"
fi
printf "Session Save [db]: "
read SESSION_SAVE
if  [ "${SESSION_SAVE}" == "" ]; then
    SESSION_SAVE="db"
fi

printf "\n"
printf "You have entered the following configuration: \n"
printf "\n"
printf "Base Url: ${BASE_URL} \n"
printf "Admin First Name: ${ADMIN_FIRSTNAME} \n"
printf "Admin Last Name: ${ADMIN_LASTNAME} \n"
printf "Admin Email: ${ADMIN_EMAIL} \n"
printf "Admin User: ${ADMIN_USER} \n"
printf "Admin Password: ${ADMIN_PASSWORD} \n"
printf "Language: ${LANGUAGE} \n"
printf "Currency: ${CURRENCY} \n"
printf "Session Save: ${SESSION_SAVE} \n"
printf "\n"
printf "Is this correct (y or n): "
read -n 1 CORRECT
printf "\n"

if  [ "${CORRECT}" == "y" ]; then

    # Install Magento
    $OPT/php/bin/php $MAGE_BIN/magento setup:install --base-url ${BASE_URL} \
    --db-host ${DB_HOST} --db-name ${DB_NAME} --db-user ${DB_USER} --db-password ${DB_PASSWORD} \
    --admin-firstname ${ADMIN_FIRSTNAME} --admin-lastname ${ADMIN_LASTNAME} --admin-email ${ADMIN_EMAIL} \
    --admin-user ${ADMIN_USER} --admin-password ${ADMIN_PASSWORD} --language ${LANGUAGE} \
    --currency ${CURRENCY} --timezone "${DATE_TIMEZONE}" --session-save ${SESSION_SAVE} \
    --cleanup-database --backend-frontname "admin" --use-rewrites 1 \
    || { 
        printf "\n" ;
        printf "Installing Magento Failed \n" ;
        printf "\n" ;
        printf "================================================================\n" ; 
        exit 1; 
        }

    printf "\n"
    printf "\n"
    printf "================================================================\n"
    printf "\n"
    printf "Magento has been installed to your specifications \n"
    printf "\n"
    printf "\n"
else
    printf "Please run this script again to enter the correct configuration. \n"
    printf "\n"
    printf "================================================================\n"
    exit 1
fi
