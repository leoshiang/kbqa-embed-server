#!/bin/bash

set -e

API_URL="http://localhost:8000"
TOKEN="my-secret-token"

header_auth="Authorization: Bearer $TOKEN"
header_json="Content-Type: application/json"

echo "🚀 測試 Embed Server API..."

echo "✅ 1. 檢查健康狀態 /healthz"
curl -s -H "$header_auth" "$API_URL/healthz" | jq .

echo "✅ 2. 測試 /embed"
curl -s -X POST "$API_URL/embed" \
  -H "$header_auth" -H "$header_json" \
  -d '{"texts": ["Hello world", "FastAPI is great!"]}' | jq .

echo "✅ 3. 測試 /embed_batch"
curl -s -X POST "$API_URL/embed_batch" \
  -H "$header_auth" -H "$header_json" \
  -d '{"texts": ["Batch embedding test", "Line two", "Line three"], "batch_size": 2}' | jq .

echo "✅ 4. 測試 /metrics"
curl -s "$API_URL/metrics" | grep "api_requests_total" | head -n 5

# 選擇性
echo "⚠️ 5. 測試 /shutdown（關閉服務）"
read -p "👉 是否關閉伺服器測試 /shutdown？(y/N): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  curl -s -X POST "$API_URL/shutdown" -H "$header_auth" | jq .
  echo "🛑 Embed server 已要求關閉。"
else
  echo "✅ 跳過關閉測試。"
fi
