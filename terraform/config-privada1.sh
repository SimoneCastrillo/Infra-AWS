#!/bin/bash
sudo apt update -y
sudo apt install -y docker.io

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
  -e EMAIL_PASSWORD="rkgw dyon uuom rjob" \
  euardopulcino/app:latest