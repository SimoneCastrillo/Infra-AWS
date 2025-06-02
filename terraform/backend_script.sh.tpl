#!/bin/bash
sudo apt update -y
sudo apt install -y docker.io docker-compose postgresql-client netcat -y

for i in {1..60}; do
  nc -z ${db_ip} 5432 && break
  echo "Esperando banco de dados ficar disponível... tentativa $i"
  sleep 5
done

# Cria arquivos docker-compose.yml e .env
cat <<EOF > /home/ubuntu/docker-compose.yml
version: '3.8'
services:
  backend:
    image: euardopulcino/app:latest
    ports:
      - "8080:8080"
    env_file:
      - .env
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://${db_ip}:5432/buffet
      - SPRING_DATASOURCE_USERNAME=buffet_user
      - SPRING_DATASOURCE_PASSWORD=password
EOF


cd /home/ubuntu
sudo docker-compose up -d
