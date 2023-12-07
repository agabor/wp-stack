#!/bin/bash

PHP_VERSION="8.2"

sudo apt update
sudo apt upgrade -y
sudo apt install -y nginx mariadb-client mariadb-server memcached software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php$PHP_VERSION-bcmath php$PHP_VERSION-cli php$PHP_VERSION-common php$PHP_VERSION-curl php$PHP_VERSION-fpm php$PHP_VERSION-gd php$PHP_VERSION-imagick php$PHP_VERSION-intl
sudo apt install -y php$PHP_VERSION-mbstring php$PHP_VERSION-mysql php$PHP_VERSION-opcache php$PHP_VERSION-readline php$PHP_VERSION-soap php$PHP_VERSION-xml php$PHP_VERSION-zip php$PHP_VERSION-memcached
