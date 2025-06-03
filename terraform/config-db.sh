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
  echo "local   all    buffet_user         md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf && \
  sudo sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf && \
  sudo systemctl restart postgresql

  if [ $? -eq 0 ]; then
    echo "Configuração do PostgreSQL concluída com sucesso."

    until sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw buffet; do
      echo "Banco ainda não disponível. Aguardando 5 segundos..."
      sleep 5
    done

    echo "Banco 'buffet' disponível. Criando schema..."

    cat <<EOF > /tmp/init_schema.sql
CREATE TABLE buffet (
    id BIGSERIAL PRIMARY KEY,
    imagem TEXT,
    descricao TEXT,
    email VARCHAR(255),
    nome VARCHAR(255) NOT NULL,
    url_site VARCHAR(255),
    telefone VARCHAR(50),
    plano VARCHAR(50)
);

CREATE TABLE tipo_evento (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    buffet_id BIGINT REFERENCES buffet(id)
);

CREATE TABLE usuario (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    senha VARCHAR(255) NOT NULL,
    telefone VARCHAR(50),
    role VARCHAR(50),
    foto TEXT,
    buffet_id BIGINT REFERENCES buffet(id)
);

CREATE TABLE decoracao (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    foto TEXT,
    tipo_evento_id INT REFERENCES tipo_evento(id),
    buffet_id BIGINT REFERENCES buffet(id)
);

CREATE TABLE endereco (
    id BIGSERIAL PRIMARY KEY,
    rua VARCHAR(255),
    numero VARCHAR(50),
    complemento VARCHAR(255),
    bairro VARCHAR(255),
    cidade VARCHAR(255),
    estado VARCHAR(100),
    cep VARCHAR(20),
    buffet_id BIGINT REFERENCES buffet(id)
);

CREATE TABLE avaliacao (
    id SERIAL PRIMARY KEY,
    nome_cliente VARCHAR(255) NOT NULL,
    texto VARCHAR(255),
    foto TEXT,
    tipo_evento_id INT REFERENCES tipo_evento(id),
    buffet_id BIGINT REFERENCES buffet(id)
);

CREATE TABLE orcamento (
    id SERIAL PRIMARY KEY,
    data_evento DATE,
    qtd_convidados INT,
    status VARCHAR(50),
    cancelado BOOLEAN,
    inicio TIME,
    fim TIME,
    sabor_bolo VARCHAR(255),
    prato_principal VARCHAR(255),
    lucro DOUBLE PRECISION,
    faturamento DOUBLE PRECISION,
    despesa DOUBLE PRECISION,
    sugestao VARCHAR(255),
    google_evento_id VARCHAR(255),
    tipo_evento_id INT REFERENCES tipo_evento(id),
    usuario_id INT REFERENCES usuario(id),
    decoracao_id INT REFERENCES decoracao(id),
    buffet_id BIGINT REFERENCES buffet(id),
    endereco_id BIGINT REFERENCES endereco(id)
);
EOF

    echo "localhost:5432:buffet:buffet_user:password" > ~/.pgpass
    chmod 600 ~/.pgpass

    psql -h localhost -U buffet_user -d buffet -f /tmp/init_schema.sql

    echo "Inserindo dados iniciais..."

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

    psql -h localhost -U buffet_user -d buffet -f /tmp/init_inserts.sql

    echo "Concedendo permissões ao usuário buffet_user..."

    sudo -u postgres psql -d buffet -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO buffet_user;"
    sudo -u postgres psql -d buffet -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO buffet_user;"
    sudo -u postgres psql -d buffet -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO buffet_user;"
    sudo -u postgres psql -d buffet -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO buffet_user;"

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
