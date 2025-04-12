#!/bin/bash

set -e

TARGET_DIR="$HOME/embed_server"
REPO_URL="https://github.com/leoshiang/kbqa-embed-server"
REPO_BRANCH="main"

# 是否跳過互動模式
AUTO_MODE=false

# 處理參數
for arg in "$@"; do
  if [[ "$arg" == "--yes" ]]; then
    AUTO_MODE=true
  fi
done

if ! $AUTO_MODE; then
  echo "🔧 是否繼續安裝 Hugging Face 嵌入伺服器？(y/N)"
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ 安裝中止。"
    exit 0
  fi
else
  echo "🟢 啟用自動模式 (--yes)"
fi

echo "📁 建立資料夾 $TARGET_DIR"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

echo "🌐 下載 GitHub 原始碼..."
git clone --branch "$REPO_BRANCH" "$REPO_URL" temp_repo
cp -r temp_repo/ubuntu/* .
rm -rf temp_repo

# 🧠 安裝 Elasticsearch
echo ""
echo "📦 安裝 Elasticsearch（for 開發環境）..."

sudo apt update
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install elasticsearch

# ✅ 一次性覆蓋 elasticsearch.yml，避免 YAML 錯誤
echo "🛠️ 寫入正確的 elasticsearch.yml（清除原有內容）"
sudo tee /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOF
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
discovery.seed_hosts: []
xpack.security.enabled: false
xpack.security.enrollment.enabled: true
xpack.security.http.ssl:
  enabled: true
  keystore.path: certs/http.p12
xpack.security.transport.ssl:
  enabled: true
  verification_mode: certificate
  keystore.path: certs/transport.p12
  truststore.path: certs/transport.p12
cluster.initial_master_nodes: ["ubuntu24042"]
EOF

# 🔁 啟動服務
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch.service
sudo systemctl restart elasticsearch

echo "🕒 等待 Elasticsearch 啟動..."
sleep 30

if curl -s http://localhost:9200 | grep cluster_name; then
  echo "✅ Elasticsearch 啟動成功！"
else
  echo "❌ Elasticsearch 啟動失敗，請檢查 journalctl -xeu elasticsearch.service"
fi

# 是否執行安裝
if $AUTO_MODE; then
  INSTALL="y"
  MONITOR="y"
  TEST="y"
else
  echo ""
  echo "🔧 是否安裝向量伺服器與 systemd 服務？(y/N)"
  read -r INSTALL

  echo "📈 是否安裝 Prometheus + Grafana 監控？(y/N)"
  read -r MONITOR

  echo "🧪 是否執行自動測試？(y/N)"
  read -r TEST
fi

if [[ "$INSTALL" == "y" || "$INSTALL" == "Y" ]]; then
  chmod +x install.sh
  ./install.sh
fi

if [[ "$MONITOR" == "y" || "$MONITOR" == "Y" ]]; then
  chmod +x monitoring.sh
  ./monitoring.sh
fi

if [[ "$TEST" == "y" || "$TEST" == "Y" ]]; then
  chmod +x test_embed_server.sh
  ./test_embed_server.sh
fi

echo ""
echo "✅ 安裝完成！API：http://localhost:8000"
echo "📊 Prometheus：http://localhost:9090"
echo "📈 Grafana：http://localhost:3000 (admin/admin)"
