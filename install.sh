#!/bin/bash

clear
echo "----------------------------------------------------------------------"
echo "   INSTALADOR AUTOMATICO JEXACTYL BR + WINGS"
echo "   DISTRIBUIDO POR: CZ7 Solutions - cz7.host"
echo "----------------------------------------------------------------------"
sleep 3

echo "Atualizando o sistema e instalando dependencias necessarias..."
apt -y update
apt -y upgrade
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

echo "Adicionando repositorio PHP..."
add-apt-repository -y ppa:ondrej/php
apt -y update

echo "Instalando PHP e extensoes..."
apt -y install php8.1 php8.1-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

echo "Instalando Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "Iniciando e habilitando servicos..."
systemctl enable --now redis-server
systemctl enable --now mariadb
systemctl enable --now nginx

echo "----------------------------------------------------------------------"
echo "CONFIGURACAO DO BANCO DE DADOS"
echo "O script vai configurar o banco automaticamente para voce."
echo "----------------------------------------------------------------------"

DB_PASSWORD=$(openssl rand -base64 14)
mysql -u root -e "CREATE DATABASE panel;"
mysql -u root -e "CREATE USER 'jexactyl'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'jexactyl'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

echo "Banco de dados criado com sucesso."
echo "Usuario: jexactyl"
echo "Senha gerada: $DB_PASSWORD"
sleep 10

echo "Baixando arquivos do Jexactyl..."
mkdir -p /var/www/jexactyl
cd /var/www/jexactyl
curl -L https://github.com/Next-Panel/Jexactyl-BR/releases/latest/download/panel.tar.gz | tar -xzv
chmod -R 755 storage/* bootstrap/cache/

echo "Instalando dependencias do painel via Composer..."
composer install --no-dev --optimize-autoloader

echo "Copiando arquivo de ambiente..."
cp .env.example .env
php artisan key:generate --force

echo "Configurando o ambiente no .env..."
php artisan p:environment:setup

echo "Configurando banco de dados no .env..."
export DB_PASSWORD
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$DB_PASSWORD/" .env
sed -i "s/DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_DATABASE=panel/DB_DATABASE=panel/" .env
sed -i "s/DB_USERNAME=jexactyl/DB_USERNAME=jexactyl/" .env

echo "Executando migracoes do banco..."
php artisan migrate --seed --force

echo "----------------------------------------------------------------------"
echo "CRIACAO DO USUARIO ADMINISTRADOR..."
echo "Preencha os dados abaixo para criar o admin do painel."
echo "----------------------------------------------------------------------"
php artisan p:user:make

echo "Definindo permissoes de arquivos..."
chown -R www-data:www-data /var/www/jexactyl/*

echo "----------------------------------------------------------------------"
echo "CONFIGURACAO DE DOMINIO E REDE"
echo "Escolha o tipo de instalacao:"
echo "1) Local / IP (Sem SSL - Apenas HTTP)"
echo "2) Dominio com SSL (HTTPS - Recomendado)"
read -p "Digite o numero da opcao (1 ou 2): " NETWORK_OPT

if [ "$NETWORK_OPT" == "2" ]; then
    echo "----------------------------------------------------------------------"
    echo "ATENCAO - CONFIGURACAO CLOUDFLARE"
    echo "Voce escolheu usar dominio."
    echo "Acesse sua conta na Cloudflare agora."
    echo "Crie um apontamento TIPO A com o nome do seu subdominio."
    echo "Aponte para o IP deste servidor."
    echo "IMPORTANTE: Deixe a nuvem CINZA (DNS Only) inicialmente para gerar o SSL."
    echo "----------------------------------------------------------------------"
    read -p "Digite seu dominio completo (ex: painel.seusite.com): " USER_DOMAIN
    read -p "Pressione ENTER apos ter configurado o DNS na Cloudflare..."
    
    echo "Instalando Certbot..."
    apt -y install certbot python3-certbot-nginx
    
    echo "Gerando certificado SSL..."
    certbot --nginx -d $USER_DOMAIN --non-interactive --agree-tos -m admin@$USER_DOMAIN
    
    cat > /etc/nginx/sites-available/jexactyl.conf <<EOF
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
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
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

    location ~ /\.ht {
        deny all;
    }
}
EOF

else
    echo "Voce escolheu usar apenas IP."
    MY_IP=$(curl -s https://ipinfo.io/ip)
    echo "Seu IP e: $MY_IP"
    
    cat > /etc/nginx/sites-available/jexactyl.conf <<EOF
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
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
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

    location ~ /\.ht {
        deny all;
    }
}
EOF
fi

ln -s /etc/nginx/sites-available/jexactyl.conf /etc/nginx/sites-enabled/jexactyl.conf
rm /etc/nginx/sites-enabled/default
service nginx restart

echo "----------------------------------------------------------------------"
echo "INSTALANDO O WINGS (DAEMON)"
echo "----------------------------------------------------------------------"

mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings

echo "Instalando Docker..."
curl -sSL https://get.docker.com/ | CHANNEL=stable bash
systemctl enable --now docker

echo "----------------------------------------------------------------------"
echo "FINALIZACAO DA INSTALACAO"
echo "INSTALADOR - CZ7 SOLUTIONS"
echo "----------------------------------------------------------------------"
echo "1. Acesse seu painel pelo navegador."
echo "2. Faca login com o usuario criado."
echo "3. Va em Admin -> Locations e crie uma Localizacao."
echo "4. Va em Admin -> Nodes e crie um Node."
echo "5. Ao criar o Node, clique na aba 'Configuration'."
echo "6. Copie o bloco de codigo de configuracao (token)."
echo "7. Cole o conteudo no arquivo: /etc/pterodactyl/config.yml"
echo "8. Apos colar, execute o comando: systemctl start wings"
echo "----------------------------------------------------------------------"
echo "Instalacao concluida!"
