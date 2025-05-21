module "net" {
  source = "../network"
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.key_pair_name
  public_key = file("id_rsa.pem.pub")
}
resource "aws_instance" "ec2-publica" {
  ami               = var.ami
  availability_zone = var.a_zone
  instance_type     = var.inst_type

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "standard"
  }

  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = module.net.subnet_public_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [module.net.sg_id]

  tags = {
    Name = "ec2-publica-terraform"
  }

  user_data = <<-EOF
#!/bin/bash

# Instala Docker e inicia
sudo apt update -y
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker

# Cria nginx.conf com IPs dinâmicos dos backends
sudo cat > /tmp/nginx.conf <<'EOF_NGINX'
upstream backend_servers {
    least_conn;
    server ${aws_instance.ec2-privada1.private_ip}:8080;
    server ${aws_instance.ec2-privada2.private_ip}:8080;
}

server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    location /api/ {
        proxy_pass http://backend_servers/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Authorization $http_authorization;
    }
}
EOF_NGINX

# Puxa imagem do Docker Hub
sudo docker pull euardopulcino/reactapp:latest

# Sobe container com nginx.conf montado
sudo docker run -d -p 80:80 \
  --name react \
  -v /tmp/nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  euardopulcino/reactapp:latest
EOF



  lifecycle {
    ignore_changes = [ami, tags]
  }
}

locals {
  google_credentials = jsonencode()
}

locals {
  db_ip = aws_instance.ec2-db.private_ip
}

resource "aws_instance" "ec2-db" {
  ami               = var.ami
  availability_zone = var.a_zone
  instance_type     = var.inst_type  # Defina o tipo adequado para o seu banco de dados

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "standard"
  }

  subnet_id         = module.net.subnet_private_id
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [module.net.sg_id]
  associate_public_ip_address = false

  tags = {
    Name = "ec2-db-terraform"
  }

  lifecycle {
    ignore_changes = [ami, tags]
  }

  user_data = file("./config-db.sh")
}

# Primeira instância privada
resource "aws_instance" "ec2-privada1" {
  ami                 = var.ami
  availability_zone   = var.a_zone
  instance_type       = var.inst_type
  depends_on          = [aws_instance.ec2-db]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "standard"
  }

  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = module.net.subnet_private_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [module.net.sg_id]

  tags = {
    Name = "ec2-privada1-terraform"
  }

  lifecycle {
    ignore_changes = [ami, tags]
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io postgresql-client netcat

    for i in {1..60}; do
      nc -z ${local.db_ip} 5432 && break
      echo "Esperando o banco de dados ficar disponível... tentativa $i"
      sleep 5
    done

    sudo docker pull euardopulcino/app:latest
    sudo docker run -d \
      --name backend \
      -p 8080:8080 \
      -e GOOGLE_CALENDAR_CREDENTIALS='${local.google_credentials}' \
      -e GOOGLE_CALENDAR_ID="dudu.castrillo@gmail.com" \
      -e SPRING_DATASOURCE_URL="jdbc:postgresql://${local.db_ip}:5432/buffet" \
      -e SPRING_DATASOURCE_USERNAME="buffet_user" \
      -e SPRING_DATASOURCE_PASSWORD="password" \
      -e EMAIL_USERNAME="dudu.castrillo@gmail.com" \
      -e EMAIL_PASSWORD="password" \
      euardopulcino/app:latest
  EOF
}

# Segunda instância privada
resource "aws_instance" "ec2-privada2" {
  # ... (mesma configuração da primeira instância, apenas o nome muda)
  ami                 = var.ami
  availability_zone   = var.a_zone
  instance_type       = var.inst_type
  depends_on          = [aws_instance.ec2-db]

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 30
    volume_type = "standard"
  }

  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = module.net.subnet_private_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [module.net.sg_id]

  tags = {
    Name = "ec2-privada2-terraform"
  }

  lifecycle {
    ignore_changes = [ami, tags]
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y docker.io postgresql-client netcat

    for i in {1..60}; do
      nc -z ${local.db_ip} 5432 && break
      echo "Esperando o banco de dados ficar disponível... tentativa $i"
      sleep 5
    done

    sudo docker pull euardopulcino/app:latest
    sudo docker run -d \
      --name backend \
      -p 8080:8080 \
      -e GOOGLE_CALENDAR_CREDENTIALS='${local.google_credentials}' \
      -e GOOGLE_CALENDAR_ID="dudu.castrillo@gmail.com" \
      -e SPRING_DATASOURCE_URL="jdbc:postgresql://${local.db_ip}:5432/buffet" \
      -e SPRING_DATASOURCE_USERNAME="buffet_user" \
      -e SPRING_DATASOURCE_PASSWORD="password" \
      -e EMAIL_USERNAME="dudu.castrillo@gmail.com" \
      -e EMAIL_PASSWORD="password" \
      euardopulcino/app:latest
  EOF
}