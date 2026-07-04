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
CREATE_RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Minha primeira task","status":"PENDING"}')
echo "$CREATE_RESPONSE"

TASK_ID=$(echo "$CREATE_RESPONSE" | grep -o '"TaskId": "[^"]*' | cut -d'"' -f4)
echo "TaskId capturado: $TASK_ID"
echo ""

echo "=== Teste 3: COM token - listar tasks ==="
curl -s "$API_URL/tasks" \
  -H "Authorization: Bearer $TOKEN"
echo ""

echo "=== Teste 4: UPDATE ==="
curl -s -X PUT "$API_URL/tasks/$TASK_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"DONE"}'
echo ""

echo "=== Teste 5: DELETE ==="
curl -s -X DELETE "$API_URL/tasks/$TASK_ID" \
  -H "Authorization: Bearer $TOKEN"
echo ""

echo "=== Teste 6: LISTAR de novo (deve vir sem essa task) ==="
curl -s "$API_URL/tasks" \
  -H "Authorization: Bearer $TOKEN"
echo ""
