#!/bin/bash

PHP_VERSION="8.2"
HOST_NAME="test.codesharp.dev"
DB_NAME="wp_test"
DB_USER="wp_test"
DB_PASS="wp_testpass"

WP_TITLE="WP Test"
WP_ADMIN_NAME="admin"
WP_ADMIN_EMAIL="admin@admin.admin"
WP_ADMIN_PASS="admin"

export DEBIAN_FRONTEND=noninteractive

sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx mariadb-client mariadb-server memcached software-properties-common curl
sudo add-apt-repository ppa:ondrej/php
sudo apt update

php_extensions=(
    "bcmath"
    "cli"
    "common"
    "curl"
    "fpm"
    "gd"
    "imagick"
    "intl"
    "mbstring"
    "mysql"
    "opcache"
    "readline"
    "soap"
    "xml"
    "zip"
    "memcached"
)

install_command=""

for ext in "${php_extensions[@]}"; do
    install_command+="php$PHP_VERSION-$ext "
done

sudo apt install -y $install_command

PHP_INI_FILE="/etc/php/$PHP_VERSION/fpm/php.ini" 

if [ -f "$PHP_INI_FILE" ]; then
    sudo sed -Ei "s/^;?\s*zend_extension\s*=\s*opcache/zend_extension=opcache/" $PHP_INI_FILE
    declare -A settings=(
        ["memory_limit"]="512M"
        ["max_execution_time"]="120"
        ["upload_max_filesize"]="64M"
        ["post_max_size"]="64M"
        ["max_input_vars"]="3000"
        ["display_errors"]="Off"
        ["session.gc_maxlifetime"]="1440"
        ["opcache.enable"]="1"
        ["file_uploads"]="On"
        ["expose_php"]="Off"
        ["session.cookie_httponly"]="1"
    )
    for setting in "${!settings[@]}"; do
        value=${settings[$setting]}
        sudo sed -Ei "s/^;?\s*$setting\s*=.*/$setting = $value/" $PHP_INI_FILE
    done
else
    echo "Error: php.ini file does not exist at $PHP_INI_FILE"
fi

sudo curl -O https://raw.githubusercontent.com/agabor/wp-stack/main/default
sudo rm /etc/nginx/sites-available/default
sudo mv default /etc/nginx/sites-available/default

sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

sudo apt remove -y certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

sudo mariadb -e "CREATE DATABASE $DB_NAME;"
sudo mariadb -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"

sudo chown www-data:www-data /var/www
sudo -u www-data wp core download --path=/var/www/wordpress
sudo -u www-data wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS
sudo -u www-data wp core install --url=https://$HOST_NAME --title=$WP_TITLE --admin_user=$WP_ADMIN_NAME --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL

sudo systemctl restart php$PHP_VERSION-fpm.service
sudo systemctl restart nginx.service
