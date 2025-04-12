#!/bin/bash

set -e

APP_NAME="embed_server"
APP_USER="$USER"
WORK_DIR="$(pwd)"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
PYTHON_EXEC=$(which python3)

echo "✅ 安裝 Python + venv..."
sudo apt update
sudo apt install -y python3 python3-pip python3-venv jq

[ -d "venv" ] || $PYTHON_EXEC -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn sentence-transformers prometheus_client

mkdir -p logs

echo "✅ 建立 systemd 服務..."
SERVICE_CONTENT="[Unit]
Description=Embed Server (with Prometheus)
After=network.target

[Service]
User=${APP_USER}
WorkingDirectory=${WORK_DIR}
ExecStart=${WORK_DIR}/venv/bin/uvicorn embed_server:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
"
echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null

sudo systemctl daemon-reexec || sudo systemctl daemon-reload
sudo systemctl enable $APP_NAME
sudo systemctl restart $APP_NAME

echo "🎯 等待伺服器啟動..."
sleep 3

# ======= ⬇ 自動測試區塊（內嵌測試腳本）⬇ =======
echo ""
echo "🚀 開始自動測試 API..."

API_URL="http://localhost:8000"
TOKEN="my-secret-token"
header_auth="Authorization: Bearer $TOKEN"
header_json="Content-Type: application/json"

echo "✅ 1. 檢查 /healthz"
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

echo ""
echo "⚠️ 5. 測試 /shutdown（選擇性）"
read -p "👉 是否關閉嵌入伺服器測試 /shutdown？(y/N): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
  curl -s -X POST "$API_URL/shutdown" -H "$header_auth" | jq .
  echo "🛑 Embed server 已關閉。"
else
  echo "✅ 跳過 /shutdown 測試。"
fi