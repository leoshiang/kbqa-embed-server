from fastapi import FastAPI, Request, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import threading
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os
import signal

# === 設定 ===
API_TOKEN = "my-secret-token"
MAX_HISTORY = 5
current_model_name = "thenlper/gte-base"

# === FastAPI 與安全設定 ===
app = FastAPI()
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    if credentials.credentials != API_TOKEN:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

# === Logging（每日輪替） ===
os.makedirs("logs", exist_ok=True)
log_formatter = logging.Formatter("%(asctime)s | %(message)s")
log_handler = TimedRotatingFileHandler("logs/server.log", when="midnight", backupCount=7)
log_handler.setFormatter(log_formatter)
log_handler.suffix = "%Y-%m-%d"
logger = logging.getLogger("uvicorn.access")
logger.setLevel(logging.INFO)
logger.addHandler(log_handler)

# === Prometheus Metrics ===
REQUEST_COUNT = Counter("api_requests_total", "Total API requests", ["method", "endpoint"])
REQUEST_TIME = Histogram("api_request_duration_seconds", "API response time", ["method", "endpoint"])

# === 模型 ===
model_lock = threading.Lock()
model = SentenceTransformer(current_model_name)
model_history = [current_model_name]

# === 資料結構 ===
class EmbedRequest(BaseModel):
    texts: list[str]

class BatchEmbedRequest(BaseModel):
    texts: list[str]
    batch_size: int | None = 32

class SwitchModelRequest(BaseModel):
    model: str

# === 中介層：Log + Metrics ===
@app.middleware("http")
async def log_and_measure(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    logger.info(f"{request.client.host} {request.method} {request.url.path} {duration*1000:.2f}ms")
    REQUEST_COUNT.labels(request.method, request.url.path).inc()
    REQUEST_TIME.labels(request.method, request.url.path).observe(duration)
    return response

# === API ===
@app.post("/embed")
async def embed(req: EmbedRequest, creds: HTTPAuthorizationCredentials = Depends(verify_token)):
    with model_lock:
        start = time.time()
        embeddings = model.encode(req.texts, normalize_embeddings=True)
    return {"embeddings": embeddings.tolist(), "time_ms": round((time.time() - start) * 1000, 2)}

@app.post("/embed_batch")
async def embed_batch(req: BatchEmbedRequest, creds: HTTPAuthorizationCredentials = Depends(verify_token)):
    with model_lock:
        start = time.time()
        embeddings = model.encode(req.texts, batch_size=req.batch_size or 32, normalize_embeddings=True)
    return {"embeddings": embeddings.tolist(), "time_ms": round((time.time() - start) * 1000, 2)}

@app.post("/switch_model")
async def switch_model(req: SwitchModelRequest, creds: HTTPAuthorizationCredentials = Depends(verify_token)):
    global model, current_model_name, model_history
    try:
        temp_model = SentenceTransformer(req.model)
        with model_lock:
            model = temp_model
            current_model_name = req.model
            if req.model in model_history:
                model_history.remove(req.model)
            model_history.insert(0, req.model)
            model_history = model_history[:MAX_HISTORY]
        return {"status": "success", "model": current_model_name}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@app.post("/reload_model_from_disk")
async def reload_model(creds: HTTPAuthorizationCredentials = Depends(verify_token)):
    global model
    try:
        with model_lock:
            model = SentenceTransformer(current_model_name, cache_folder=None)
        return {"status": "reloaded", "model": current_model_name}
    except Exception as e:
        return {"status": "error", "error": str(e)}

@app.post("/shutdown")
async def shutdown(creds: HTTPAuthorizationCredentials = Depends(verify_token)):
    os.kill(os.getpid(), signal.SIGTERM)
    return {"status": "shutting down"}

@app.get("/metrics")
async def metrics():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/healthz")
async def healthz():
    try:
        with model_lock:
            model.encode(["ping"], normalize_embeddings=True)
        return {"status": "ok", "model": current_model_name}
    except Exception as e:
        return {"status": "error", "error": str(e)}