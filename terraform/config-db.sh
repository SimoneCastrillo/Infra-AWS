#!/bin/bash

max_retries=5
count=0
success=0

while [ $count -lt $max_retries ]; do
  echo "Tentativa $((count+1)) de configurar PostgreSQL..."

  sudo apt-get update -y && \
  sudo apt-get install -y postgresql postgresql-contrib && \
  sudo -u postgres psql -c "CREATE USER buffet_user WITH PASSWORD 'password';" && \
  sudo -u postgres psql -c "CREATE DATABASE buffet;" && \
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE buffet TO buffet_user;" && \
  echo "host    all    all    10.0.0.0/24    md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf && \
  sudo sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf && \
  sudo systemctl restart postgresql

  if [ $? -eq 0 ]; then
    echo "Configuração do PostgreSQL concluída com sucesso."
    success=1
    break
  else
    echo "Falha na configuração. Tentando novamente em 10 segundos..."
    count=$((count+1))
    sleep 10
  fi
done

if [ $success -ne 1 ]; then
  echo "Falhou após $max_retries tentativas."
fi
