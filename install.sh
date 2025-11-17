#!/bin/bash

clear
echo "----------------------------------------------------------------------"
echo "   INSTALADOR AUTOMATICO JEXACTYL BR + WINGS (UNIVERSAL)"
echo "   AUTORIA: CARLOS DAVI FERREIRA CAFERRO"
echo "   ORGANIZACAO: CZ7 Solutions"
echo "----------------------------------------------------------------------"
sleep 3

OS_ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
WEB_USER="www-data"
PHP_SOCKET=""
PHP_SERVICE=""

echo "Sistema detectado: $OS_ID"
sleep 2

if [[ "$OS_ID" == "ubuntu" ]] || [[ "$OS_ID" == "debian" ]]; then
    echo "Iniciando instalacao para base Debian/Ubuntu..."
    apt -y update
    apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg lsb-release

    if [[ "$OS_ID" == "ubuntu" ]]; then
        add-apt-repository -y ppa:ondrej/php
    else
        curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
        echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
        apt -y update
    fi

    apt -y install php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server
    
    WEB_USER="www-data"
    PHP_SOCKET="/run/php/php8.1-fpm.sock"
    PHP_SERVICE="php8.1-fpm"

elif [[ "$OS_ID" == "fedora" ]] || [[ "$OS_ID" == "centos" ]] || [[ "$OS_ID" == "almalinux" ]] || [[ "$OS_ID" == "rocky" ]]; then
    echo "Iniciando instalacao para base RHEL/Fedora..."
    
    if [[ "$OS_ID" == "fedora" ]]; then
        dnf -y install https://rpms.remirepo.net/fedora/remi-release-$(rpm -E %fedora).rpm
    else
        dnf -y install epel-release
        dnf -y install https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm
    fi
    
    dnf -y module reset php
    dnf -y module enable php:remi-8.1
    dnf -y install php php-{common,cli,gd,mysqlnd,mbstring,bcmath,xml,fpm,curl,zip,json} mariadb-server nginx tar unzip git redis

    WEB_USER="nginx"
    PHP_SOCKET="/run/php-fpm/www.sock"
    PHP_SERVICE="php-fpm"
    
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
    
    sed -i 's/apache/nginx/g' /etc/php-fpm.d/www.conf
    
else
    echo "Sistema Operacional nao suportado automaticamente."
    exit 1
fi

echo "Instalando Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "Iniciando e habilitando servicos..."
systemctl enable --now redis
systemctl enable --now mariadb
systemctl enable --now nginx
systemctl enable --now $PHP_SERVICE

echo "----------------------------------------------------------------------"
echo "CONFIGURACAO DO BANCO DE DADOS"
echo "----------------------------------------------------------------------"

DB_PASSWORD=$(openssl rand -base64 14)
mysql -u root -e "CREATE DATABASE panel;"
mysql -u root -e "CREATE USER 'jexactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'jexactyl'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "Banco configurado. Senha: $DB_PASSWORD"
sleep 2

echo "Baixando arquivos do Jexactyl..."
mkdir -p /var/www/jexactyl
cd /var/www/jexactyl
curl -L https://github.com/Next-Panel/Jexactyl-BR/releases/latest/download/panel.tar.gz | tar -xzv
chmod -R 755 storage/* bootstrap/cache/

echo "Instalando dependencias do painel..."
composer install --no-dev --optimize-autoloader

echo "Configurando .env..."
cp .env.example .env
php artisan key:generate --force
php artisan p:environment:setup

export DB_PASSWORD
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_DATABASE=panel/DB_DATABASE=panel/" .env
sed -i "s/DB_USERNAME=jexactyl/DB_USERNAME=jexactyl/" .env

echo "Executando migracoes..."
php artisan migrate --seed --force

echo "----------------------------------------------------------------------"
echo "CRIACAO DO USUARIO ADMINISTRADOR (CARLOS DAVI FERREIRA CAFERRO)"
echo "----------------------------------------------------------------------"
php artisan p:user:make

echo "Ajustando permissoes para usuario web: $WEB_USER"
chown -R $WEB_USER:$WEB_USER /var/www/jexactyl/*

echo "----------------------------------------------------------------------"
echo "CONFIGURACAO DE DOMINIO E REDE"
echo "1) Local / IP (HTTP)"
echo "2) Dominio com SSL (HTTPS)"
read -p "Opcao (1 ou 2): " NETWORK_OPT

if [ "$NETWORK_OPT" == "2" ]; then
    echo "----------------------------------------------------------------------"
    echo "ATENCAO CLOUDFLARE: Aponte seu subdominio (Tipo A) para o IP."
    echo "Use nuvem CINZA (DNS Only) para gerar o SSL."
    echo "----------------------------------------------------------------------"
    read -p "Dominio completo (ex: painel.host.com): " USER_DOMAIN
    read -p "Pressione ENTER apos configurar o DNS..."
    
    if [[ "$OS_ID" == "fedora" ]] || [[ "$OS_ID" == "centos" ]] || [[ "$OS_ID" == "almalinux" ]] || [[ "$OS_ID" == "rocky" ]]; then
        dnf -y install certbot python3-certbot-nginx
    else
        apt -y install certbot python3-certbot-nginx
    fi
    
    certbot --nginx -d $USER_DOMAIN --non-interactive --agree-tos -m admin@$USER_DOMAIN
    
    cat > /etc/nginx/conf.d/jexactyl.conf <<EOF
server {
    listen 80;
    server_name $USER_DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $USER_DOMAIN;
    root /var/www/jexactyl/public;
    index index.php;

    access_log /var/log/nginx/jexactyl.app-access.log;
    error_log  /var/log/nginx/jexactyl.app-error.log error;

    ssl_certificate /etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$USER_DOMAIN/privkey.pem;
    
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:$PHP_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    location ~ /\.ht { deny all; }
}
EOF

else
    MY_IP=$(curl -s https://ipinfo.io/ip)
    echo "IP detectado: $MY_IP"
    
    cat > /etc/nginx/conf.d/jexactyl.conf <<EOF
server {
    listen 80;
    server_name $MY_IP;
    root /var/www/jexactyl/public;
    index index.php;

    access_log /var/log/nginx/jexactyl.app-access.log;
    error_log  /var/log/nginx/jexactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:$PHP_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    location ~ /\.ht { deny all; }
}
EOF
fi

rm -rf /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "----------------------------------------------------------------------"
echo "INSTALANDO WINGS E DOCKER"
echo "----------------------------------------------------------------------"

mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings

curl -sSL https://get.docker.com/ | CHANNEL=stable bash
systemctl enable --now docker

echo "----------------------------------------------------------------------"
echo "FINALIZADO - BY CZ7 SOLUTIONS (CARLOS DAVI FERREIRA CAFERRO)"
echo "----------------------------------------------------------------------"
echo "1. Acesse o painel no navegador."
echo "2. Login com o usuario criado."
echo "3. Crie Localizacao e Node no Admin."
echo "4. Copie o config do Node (YAML)."
echo "5. Cole em: /etc/pterodactyl/config.yml"
echo "6. Rode: systemctl start wings"
echo "----------------------------------------------------------------------"
