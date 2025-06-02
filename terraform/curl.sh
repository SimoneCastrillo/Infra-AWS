curl -X POST http://10.0.0.190:8080/buffets \
  -F "descricao=Casa de Eventos da Simone Castrillo, venha se divertir e fazer uma festa incrivel" \
  -F "email=simone.castrillo@gmail.com" \
  -F "nome=Simone Castrillo Eventos" \
  -F "plano=BASICO" \
  -F "telefone=11953311150" \
  -F "url_site=https://" \
  -F "imagem=@CastrilloEventos.png"

curl -X POST http://10.0.0.190:8080/enderecos \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1,
    "bairro": "Parque Fernanda",
    "cep": "05889380",
    "cidade": "São Paulo",
    "complemento": "Casa",
    "estado": "SP",
    "numero": "330",
    "rua": "Rua General Ribamar de Miranda",
    "buffetId": 1
}'