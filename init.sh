#!/bin/bash

PHP_VERSION="8.2"

export DEBIAN_FRONTEND=noninteractive

sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx mariadb-client mariadb-server memcached software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php$PHP_VERSION-bcmath php$PHP_VERSION-cli php$PHP_VERSION-common php$PHP_VERSION-curl php$PHP_VERSION-fpm php$PHP_VERSION-gd php$PHP_VERSION-imagick php$PHP_VERSION-intl
sudo apt install -y php$PHP_VERSION-mbstring php$PHP_VERSION-mysql php$PHP_VERSION-opcache php$PHP_VERSION-readline php$PHP_VERSION-soap php$PHP_VERSION-xml php$PHP_VERSION-zip php$PHP_VERSION-memcached

PHP_INI_FILE="/etc/php/$PHP_VERSION/fpm/php.ini" 

if [ -f "$PHP_INI_FILE" ]; then
    sudo sed -i "s/^;?\s*memory_limit\s*=.*/memory_limit = 512M/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*max_execution_time\s*=.*/max_execution_time = 120/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*upload_max_filesize\s*=.*/upload_max_filesize = 64M/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*post_max_size\s*=.*/post_max_size = 64M/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*max_input_vars\s*=.*/max_input_vars = 3000/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*display_errors\s*=.*/display_errors = Off/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*session.gc_maxlifetime\s*=.*/session.gc_maxlifetime = 1440/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*zend_extension\s*=\s*opcache/zend_extension=opcache/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*opcache.enable\s*=.*/opcache.enable = 1/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*file_uploads\s*=.*/file_uploads = On/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*expose_php\s*=.*/expose_php = Off/" $PHP_INI_FILE
    sudo sed -i "s/^;?\s*session.cookie_httponly\s*=.*/session.cookie_httponly = 1/" $PHP_INI_FILE
else
    echo "Error: php.ini file does not exist at $PHP_INI_FILE"
fi

sudo apt remove -y certbot
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
