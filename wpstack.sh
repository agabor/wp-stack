#!/bin/bash

if [ ! -f ~/wpstack.cfg ]; then
    curl -o ~/wpstack.cfg https://raw.githubusercontent.com/agabor/wp-stack/main/wpstack.cfg
fi

source ~/wpstack.cfg

#Initial install steps
APT_UPGRADE=0
INSTALL_BASICS=0
INSTALL_PHP=0
CONFIG_PHP=0
CONFIG_NGINX=0
CONFIG_NGINX_HOST=0
INSTALL_WP_CLI=0
INSTALL_CERTBOT=0
REQUEST_CERT=0
CREATE_DB=0
INSTALL_WP=0

#Tools
RECREATE_DB=0
UPDATE=0

if [ $# -gt 0 ]; then
    if [ "$1" = "INIT" ]; then
        INSTALL_BASICS=1
        INSTALL_PHP=1
        CONFIG_PHP=1
        CONFIG_NGINX=1
        CONFIG_NGINX_HOST=1
        INSTALL_WP_CLI=1
        INSTALL_CERTBOT=1
        REQUEST_CERT=1
        CREATE_DB=1
        INSTALL_WP=1
    else
        for arg in "$@"; do
            declare "$arg=1"
        done
    fi
else
    echo "No command is given. Possible commands:"
    echo "APT_UPGRADE"
    echo "Server initialization steps:"
    echo "INSTALL_BASICS"
    echo "INSTALL_PHP"
    echo "CONFIG_PHP"
    echo "CONFIG_NGINX"
    echo "CONFIG_NGINX_HOST"
    echo "INSTALL_WP_CLI"
    echo "INSTALL_CERTBOT"
    echo "REQUEST_CERT"
    echo "CREATE_DB"
    echo "INSTALL_WP"
    echo "Use the INIT command to run all server initialization steps!"
    echo "Tools:"
    echo "RECREATE_DB"
    echo "UPDATE"
fi

export DEBIAN_FRONTEND=noninteractive

if [ $APT_UPGRADE -eq 1 ]; then
    echo "APT upgrade and reboot"
    sudo apt update
    sudo apt upgrade -y
    sudo reboot
fi

if [ $INSTALL_BASICS -eq 1 ]; then
    echo "Installing basic software (NGINX, MariaDB, Memcached, etc.)"
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y nginx mariadb-client mariadb-server memcached software-properties-common curl
fi

if [ $INSTALL_PHP -eq 1 ]; then
    echo "Installing PHP $PHP_VERSION modules"
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
fi


if [ $CONFIG_PHP -eq 1 ]; then
    echo "Configuring PHP for WordPress";
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
        sudo systemctl restart php$PHP_VERSION-fpm.service
    else
        echo "Error: php.ini file does not exist at $PHP_INI_FILE"
    fi
fi

if [ $CONFIG_NGINX -eq 1 ]; then
    echo "Configuring NGINX for WordPress";
    NGINX_CONF="/etc/nginx/nginx.conf"
    sudo rm $NGINX_CONF
    sudo curl -o $NGINX_CONF https://raw.githubusercontent.com/agabor/wp-stack/main/nginx.conf
    sudo nginx -t
    sudo systemctl restart nginx.service
fi

if [ $CONFIG_NGINX_HOST -eq 1 ]; then
    echo "Configuring NGINX host for WordPress";
    NGINX_HOST_CONF="/etc/nginx/sites-available/default" 
    sudo rm $NGINX_HOST_CONF
    sudo curl -o $NGINX_HOST_CONF https://raw.githubusercontent.com/agabor/wp-stack/main/default
    sudo sed -Ei "s/^\s*server_name _;/        server_name $HOST_NAME;/" $NGINX_HOST_CONF
    sudo sed -Ei "s/^\s*fastcgi_pass unix:\/run\/php\/php8.2-fpm.sock;/                fastcgi_pass unix:\/run\/php\/php$PHP_VERSION-fpm.sock;/" $NGINX_HOST_CONF
    sudo nginx -t
    sudo systemctl restart nginx.service
fi

if [ $INSTALL_WP_CLI -eq 1 ]; then
    echo "Installing WordPress CLI";
    sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    sudo chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
fi

if [ $INSTALL_CERTBOT -eq 1 ]; then
    echo "Installing Certbot";
    sudo apt remove -y certbot
    sudo snap install --classic certbot
    sudo ln -s /snap/bin/certbot /usr/bin/certbot
fi

if [ $REQUEST_CERT -eq 1 ]; then
    echo "Requesting SSL certificate"
    sudo certbot --nginx -n -d $HOST_NAME --agree-tos --email $WP_ADMIN_EMAIL
    sudo systemctl restart nginx.service
fi

if [ $CREATE_DB -eq 1 ]; then
    echo "Creating database in MariaDB server."
    sudo mariadb -e "CREATE DATABASE $DB_NAME;"
    sudo mariadb -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    sudo mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
fi

if [ $INSTALL_WP -eq 1 ]; then
    echo "Installing WordPress"
    sudo chown www-data:www-data /var/www
    sudo -u www-data wp core download --path=$WP_PATH
    sudo -u www-data wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --path=$WP_PATH
    sudo -u www-data wp core install --url=https://$HOST_NAME --title="$WP_TITLE" --admin_user="$WP_ADMIN_NAME" --admin_password="$WP_ADMIN_PASS" --admin_email=$WP_ADMIN_EMAIL --path=$WP_PATH
fi

if [ $RECREATE_DB -eq 1 ]; then
    echo "Dropping and recreating database"
    config_path="$WP_PATH/wp-config.php"
    DB_NAME=$(grep DB_NAME $config_path | awk -F "'" '{print $4}')
    DB_USER=$(grep DB_USER $config_path | awk -F "'" '{print $4}')
    DB_PASS=$(grep DB_PASSWORD $config_path | awk -F "'" '{print $4}')
    
    sudo mariadb -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
    sudo mariadb -e "DROP DATABASE IF EXISTS $DB_NAME;"
    sudo mariadb -e "CREATE DATABASE $DB_NAME;"
    sudo mariadb -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    sudo mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
fi

if [ $UPDATE -eq 1 ]; then
    echo "Running self update"
    sudo curl -o /usr/local/bin/wpstack https://raw.githubusercontent.com/agabor/wp-stack/main/wpstack.sh
    sudo chmod +x /usr/local/bin/wpstack
fi
