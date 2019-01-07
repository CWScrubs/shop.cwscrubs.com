greathouse-wordpress
====
# How to Install
These instructions assume that you've already created a useable database for your Wordpess installation, along with having the required credentials. If you need help on creating a database, you can [learn how, here](https://codex.wordpress.org/Installing_WordPress#Step_2:_Create_the_Database_and_a_User).

* Download the git repository
    * `git clone https://greathouse.technology/web/greathouse-wordpress.git`
* Change to the greathouse-wordpress directory
    * `cd greathouse-wordpress`

## Docker Installation
* The easiest way to run greathouse-wordpress is with Docker. You will need to install docker on your web host. Check the [Official Docker Site](https://docs.docker.com/engine/installation/) on how to install Docker on your host.
    * [Ubuntu](https://docs.docker.com/engine/installation/linux/ubuntu/)
    * [Red Hat Enterprise Linux](https://docs.docker.com/engine/installation/linux/rhel/)
    * [CentOs](https://docs.docker.com/engine/installation/linux/centos/)
    * [Fedora](https://docs.docker.com/engine/installation/linux/fedora/)
    * [Debian](https://docs.docker.com/engine/installation/linux/debian/)
    * [OSX](https://docs.docker.com/docker-for-mac/install/)
    * [Windows](https://docs.docker.com/docker-for-windows/install/)
    * [Docker EE for Windows Server](https://docs.docker.com/docker-ee-for-windows/install/)
    * [Docker-AWS](https://docs.docker.com/docker-for-aws/)
    * [Docker-Azure](https://docs.docker.com/docker-for-azure/)
* Run the configuration script
    * `bin/configure-docker.sh`


# Docker Management Instructions
## Building the App
    docker build -t jessegreathouse/greathouse-wordpress .

## Pushing the App
    docker push jessegreathouse/greathouse-wordpress

## Running the APP
    docker run -d -p 3000:3000 \
        -e ENV=prod \
        -e DEBUG=false \
        -e FORCE_SSL=__FORCE_SSL__ \
        -e DIR="/app" \
        -e BIN="/app/bin" \
        -e ETC="/app/etc" \
        -e OPT="/app/opt" \
        -e SRC="/app/src" \
        -e TMP="/app/tmp" \
        -e VAR="/app/var" \
        -e WEB="/app/web" \
        -e CACHE_DIR="/app/var/cache" \
        -e LOG_DIR="/app/var/logs" \
        -e REDIS_HOST=redis \
        -e DB_NAME="db_name" \
        -e DB_USER="db_user" \
        -e DB_PASSWORD="db_password" \
        -e DB_HOST="192.168.0.1" \
        -e DB_PORT=3306 \
        -v $(pwd)/error.log:/app/error.log \
        -v $(pwd)/supervisord.log:/app/supervisord.log \
        -v $(pwd)/web/wp-authentication-keys.php:/app/web/wp-authentication-keys.php \
        -v $(pwd)/web/wp-config.php:/app/web/wp-config.php \
        -v $(pwd)/etc/nginx/nginx.conf:/app/etc/nginx/nginx.conf \
        -v $(pwd)/etc/php/php.ini:/app/etc/php/php.ini \
        -v $(pwd)/etc/php/php-fpm.conf:/app/etc/php/php-fpm.conf \
        -v $(pwd)/web/wp-content/plugins:/app/web/wp-content/plugins \
        -v $(pwd)/web/wp-content/themes:/app/web/wp-content/themes \
        -v $(pwd)/web/wp-content/uploads:/app/web/wp-content/uploads \
        --restart no \
        --name my-site \
        jessegreathouse/greathouse-wordpress

* check [http://localhost:3000/](http://localhost:3000/)

# Running Tests
    docker exec -ti greathouse-wordpresss run_tests.sh
