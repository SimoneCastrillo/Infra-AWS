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

    # Cria arquivo SQL com inserts
    cat <<EOF > /tmp/init_inserts.sql
INSERT INTO buffet (id, descricao, email, nome, plano, telefone, url_site ) VALUES
(1,'Casa de Eventos da Simone Castrillo, venha se divertir e fazer uma festa incrivel', 'simone.castrillo@gmail.com', 'Simone Castrillo Eventos', 'PREMIUM', '11953311150', 'https//');

INSERT INTO endereco (id, bairro, cep, cidade, complemento, estado, numero, rua, buffet_id) VALUES
(1, 'Parque Fernanda', '05889380', 'São Paulo', 'Casa', 'SP', '330', 'Rua General Ribamar de Miranda', 1);

INSERT INTO tipo_evento (nome, buffet_id) VALUES
('INFANTIL', 1),
('CASAMENTO', 1),
('DEBUTANTE', 1),
('COFFEE_BREAK', 1),
('ANIVERSARIO', 1),
('ALUGUEL_ESPACO', 1),
('OUTROS', 1);

INSERT INTO usuario (id, nome, email, senha, telefone, role, foto, buffet_id) VALUES
(1, 'Admin', 'admin@admin.com', '\$2a\$10\$cuFV.4t1ZN5QXJhjMjC3guQfusJyw0uQiAw/unrL6ch1P2W9V1hvW', '11999990000', 'ADMIN', NULL, 1),
(2, 'Nexora', 'nexora@nexora.com', '\$2a\$10\$cuFV.4t1ZN5QXJhjMjC3guQfusJyw0uQiAw/unrL6ch1P2W9V1hvW', '11999990001', 'NEXORA_ADMIN', NULL, NULL),
(3, 'Usuario', 'usuario@usuario.com', '\$2a\$10\$cuFV.4t1ZN5QXJhjMjC3guQfusJyw0uQiAw/unrL6ch1P2W9V1hvW', '1199782111', 'USUARIO', NULL, 1);
EOF

    # Executa inserts no banco buffet com usuário buffet_user
    sudo -u postgres psql -d buffet -f /tmp/init_inserts.sql

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
