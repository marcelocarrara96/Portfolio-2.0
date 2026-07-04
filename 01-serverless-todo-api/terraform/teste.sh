#!/bin/bash

# <<< COLE O api_url NO LUGAR ABAIXO >>>
API_URL="https://mkwfra7f3g.execute-api.us-east-1.amazonaws.com/prod"
TOKEN=$(cat token.txt)

echo "=== Teste 1: SEM token (deve dar Unauthorized) ==="
curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title":"teste"}'
echo ""

echo "=== Teste 2: COM token - criar task ==="
curl -s -X POST "$API_URL/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Minha primeira task","status":"PENDING"}'
echo ""

echo "=== Teste 3: COM token - listar tasks ==="
curl -s "$API_URL/tasks" \
  -H "Authorization: Bearer $TOKEN"
echo ""