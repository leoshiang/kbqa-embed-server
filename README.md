# KBQA 嵌入伺服器（Hugging Face Embed Server）

這是一套可快速部署的 Hugging Face 向量嵌入伺服器（FastAPI 實作），支援：

- ✅ 文字轉向量 `/embed`
- ✅ 批次嵌入 `/embed_batch`
- ✅ 模型切換、重新載入、關機
- ✅ API Token 認證保護
- ✅ Prometheus 指標 `/metrics`
- ✅ Grafana 監控整合
- ✅ systemd 服務自動啟動
- ✅ 安裝腳本 + 測試腳本 + Swagger 規格 + 中文 API 文件

## 一鍵安裝方式（Ubuntu 24.04.2）

```bash
curl -sL https://raw.githubusercontent.com/leoshiang/kbqa-embed-server/main/ubuntu/setup.sh | bash -s -- --yes
```

> 預設會：
>
> - 建立 `~/embed_server` 目錄
> - 複製程式碼並自動部署
> - 啟動服務＋安裝 Prometheus/Grafana
> - 執行測試

安裝完成之後，可用瀏覽器開啟以下網址

> 可以將 localhost 換成 ip

API：http://localhost:8000
Prometheus：http://localhost:9090
Grafana：http://localhost:3000 (admin/admin)

## 功能概覽

| 功能                               | 支援 |
| ---------------------------------- | ---- |
| 向量嵌入 `/embed`                  | ✅    |
| 批次嵌入 `/embed_batch`            | ✅    |
| 模型切換 `/switch_model`           | ✅    |
| 模型重載 `/reload_model_from_disk` | ✅    |
| 關閉伺服器 `/shutdown`             | ✅    |
| 健康檢查 `/healthz`                | ✅    |
| Prometheus `/metrics`              | ✅    |
| Swagger UI 自訂版                  | ✅    |
| Grafana + Prometheus               | ✅    |
| 中文 API 文件                      | ✅    |

------

## 測試方式（已內建於 test_embed_server.sh）

```bash
cd ~/embed_server
./test_embed_server.sh
```

> 測試內容包含：
>
> - /healthz
> - /embed
> - /embed_batch
> - /metrics
> - 可選擇是否關閉伺服器（/shutdown）

## 🛠 開發者建議

- 認證 Token 請修改於 `embed_server.py` 中的 `API_TOKEN`
- 支援 Hugging Face 上的任何 `sentence-transformers` 類模型
- 記得開啟 port `8000`、Prometheus 預設 `9090`、Grafana `3000`

## API 說明文件

### 認證方式

所有保護的 API 必須加上以下 Header：

```
Authorization: Bearer my-secret-token
```

### `/embed` - 單次向量嵌入

- **方法**：`POST`
- **說明**：將一組或多組文字轉換成向量
- **是否需認證**：✅ 是

#### 請求格式

```json
{
  "texts": ["你好", "FastAPI 是什麼？"]
}
```

#### `curl` 範例

```bash
curl -X POST http://localhost:8000/embed \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{"texts": ["你好", "FastAPI 是什麼？"]}'
```

#### 回應格式

```json
{
  "embeddings": [
    [0.12, 0.34, 0.56, ...],
    [0.23, 0.45, 0.67, ...]
  ],
  "time_ms": 35.4
}
```

### `/embed_batch` - 批次向量嵌入

- **方法**：`POST`
- **說明**：用於大批文字，支援自訂 batch_size
- **是否需認證**：✅ 是

#### 請求格式

```json
{
  "texts": ["第一句", "第二句", "第三句"],
  "batch_size": 2
}
```

#### `curl` 範例

```bash
curl -X POST http://localhost:8000/embed_batch \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{"texts": ["第一句", "第二句", "第三句"], "batch_size": 2}'
```

### `/switch_model` - 切換模型

- **方法**：`POST`
- **說明**：從 Hugging Face 切換模型（需有 internet 或已快取）
- **是否需認證**：✅ 是

#### 請求格式

```json
{
  "model": "shibing624/text2vec-base-chinese"
}
```

#### `curl` 範例

```bash
curl -X POST http://localhost:8000/switch_model \
  -H "Authorization: Bearer my-secret-token" \
  -H "Content-Type: application/json" \
  -d '{"model": "shibing624/text2vec-base-chinese"}'
```

### `/reload_model_from_disk` - 重新載入模型

- **方法**：`POST`
- **說明**：重新從磁碟快取載入目前模型
- **是否需認證**：✅ 是

#### `curl` 範例

```bash
curl -X POST http://localhost:8000/reload_model_from_disk \
  -H "Authorization: Bearer my-secret-token"
```

### `/shutdown` - 關閉伺服器

- **方法**：`POST`
- **說明**：會將伺服器關閉（使用 systemd 管理時會自動停止）
- **是否需認證**：✅ 是

#### `curl` 範例

```bash
curl -X POST http://localhost:8000/shutdown \
  -H "Authorization: Bearer my-secret-token"
```

### `/healthz` - 健康檢查

- **方法**：`GET`
- **說明**：檢查模型是否載入成功
- **是否需認證**：❌ 否

#### `curl` 範例

```bash
curl http://localhost:8000/healthz
```

#### 回應範例

```json
{
  "status": "ok",
  "model": "thenlper/gte-base"
}
```

### `/metrics` - Prometheus 監控指標

- **方法**：`GET`
- **說明**：提供 Prometheus 可讀取的監控格式（無需認證）
- **是否需認證**：❌ 否

#### `curl` 範例

```bash
curl http://localhost:8000/metrics
```

## 補充說明

- 向量為 `float32` 陣列，長度依模型而異（如 768 維）
- 每次請求皆計算時間並回傳 `time_ms`
- `/embed` 與 `/embed_batch` 使用相同模型，可動態切換

## 授權 License

MIT © 2024 [leoshiang](https://github.com/leoshiang)