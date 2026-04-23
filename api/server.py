import json
import queue
import threading
from pathlib import Path
from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from agent.trend_agent import run_trend_agent
import uvicorn
import os

app = FastAPI(title="Trend-to-SKU Translator", version="1.0.0")

BASE_DIR = Path(__file__).resolve().parents[1]
FRONTEND_DIR = BASE_DIR / "frontend"
FRONTEND_DIST_DIR = FRONTEND_DIR / "dist"
ASSETS_DIR = FRONTEND_DIST_DIR / "assets"

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

if ASSETS_DIR.exists():
    app.mount("/assets", StaticFiles(directory=str(ASSETS_DIR)), name="assets")


@app.get("/")
async def root():
    index_path = FRONTEND_DIST_DIR / "index.html"
    if index_path.exists():
        return FileResponse(str(index_path))
    return FileResponse(str(FRONTEND_DIR / "index.html"))


@app.get("/health")
async def health():
    return {"status": "alive", "service": "Trend-to-SKU Translator", "agent": "Strands + Claude Sonnet 4"}


class TrendRequest(BaseModel):
    trend: str

    @field_validator("trend")
    @classmethod
    def validate_trend(cls, v):
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Trend input must be at least 3 characters")
        if len(v) > 300:
            raise ValueError("Trend input must be under 300 characters")
        return v


@app.post("/api/generate-skus")
async def generate_skus(request: TrendRequest):
    step_queue = queue.Queue()
    result_holder = [None]

    def agent_worker():
        result_holder[0] = run_trend_agent(request.trend, step_queue=step_queue)
        step_queue.put(None)  # sentinel to signal completion

    thread = threading.Thread(target=agent_worker, daemon=True)
    thread.start()

    def event_stream():
        while True:
            try:
                item = step_queue.get(timeout=120)
            except queue.Empty:
                yield f"data: {json.dumps({'type': 'error', 'title': 'Timeout', 'detail': 'Agent took too long'})}\n\n"
                break
            if item is None:
                # Agent finished — send the final result
                result = result_holder[0]
                if result and not result.get("error"):
                    yield f"data: {json.dumps({'type': 'result', 'data': result})}\n\n"
                else:
                    msg = result.get("message", "Agent failed") if result else "No response"
                    yield f"data: {json.dumps({'type': 'error', 'title': 'Agent Error', 'detail': msg})}\n\n"
                break
            else:
                yield f"data: {json.dumps(item)}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


if __name__ == "__main__":
    uvicorn.run("api.server:app", host="0.0.0.0", port=8000, reload=True)
