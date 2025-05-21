#!/bin/bash

# Atualiza os pacotes da máquina
sudo apt update -y

# Instala o Nginx
sudo apt install nginx -y

# Inicia o serviço do Nginx e habilita para iniciar automaticamente no boot
sudo systemctl start nginx
sudo systemctl enable nginx

# Configura o balanceamento de carga no Nginx
sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/default
# upstream pages {
#     server <10.0.0.202>;
#     server <10.0.0.247>;
# }

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    location / {
        proxy_pass http://pages;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF'

# Substitui os placeholders pelos IPs das máquinas privadas
sudo sed -i "s/<10.0.0.202>/$(dig +short ec2-privada1-terraform)/" /etc/nginx/sites-available/default
sudo sed -i "s/<10.0.0.247>/$(dig +short ec2-privada2-terraform)/" /etc/nginx/sites-available/default

# Reinicia o Nginx para aplicar as alterações
sudo systemctl restart nginx