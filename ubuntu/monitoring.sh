#!/bin/bash

set -e

echo "📦 安裝 Prometheus..."
sudo apt install -y prometheus

echo "📦 安裝 Grafana..."
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install -y grafana

echo "🔧 配置 Prometheus 抓 embed_server metrics..."
sudo tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOF

  - job_name: 'embed_server'
    static_configs:
      - targets: ['localhost:8000']
EOF

echo "✅ 啟動服務..."
sudo systemctl restart prometheus
sudo systemctl enable prometheus

sudo systemctl restart grafana-server
sudo systemctl enable grafana-server

echo "✅ Prometheus: http://localhost:9090"
echo "✅ Grafana:    http://localhost:3000  (預設 admin/admin)"