# Approach: Trend-to-SKU Translator

## Overview
The Trend-to-SKU Translator is an AI-powered system that converts fashion trends into actionable SKU (Stock Keeping Unit) recommendations. It leverages multi-agent architecture with Claude AI to analyze trends and generate product variants.

## Architecture

### System Components

1. **FastAPI Backend** (`api/server.py`)
   - REST API server running on port 8000
   - Handles trend analysis requests
   - Streams real-time agent progress updates
   - Serves frontend static files

2. **AI Agent** (`agent/trend_agent.py`)
   - Multi-step reasoning with Strands agents framework
   - Integrates with Claude Sonnet 4 for intelligence
   - Uses external tools for trend research:
     - Serper API (Google search)
     - Tavily API (web search and analysis)
   - Generates SKU recommendations with reasoning

3. **Frontend** (`frontend/`)
   - React + Vite single-page application
   - Real-time streaming UI for agent progress
   - Interactive trend input and SKU display
   - Responsive design for mobile/desktop

4. **Docker Deployment**
   - Multi-stage build: Node.js (frontend) + Python (backend)
   - Single container runs entire application
   - Optimized for AWS App Runner

## Workflow

```
User Input (Trend)
    ↓
FastAPI Endpoint (/api/generate-skus)
    ↓
Trend Agent (Multi-step reasoning)
    ├─ Search for trend information
    ├─ Analyze competitor products
    ├─ Generate SKU variants
    └─ Stream progress updates
    ↓
SKU Recommendations (with reasoning)
    ↓
Frontend displays results
```

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React 18, Vite, JavaScript |
| **Backend** | FastAPI, Python 3.11, Uvicorn |
| **AI/ML** | Strands Agents, Claude Sonnet 4 |
| **External APIs** | Serper, Tavily, AWS Bedrock |
| **Deployment** | Docker, AWS App Runner |
| **Infrastructure** | AWS ECR, AWS IAM |

## Key Design Decisions

### 1. Streaming API Response
**Why:** Trends analysis can take 30-60 seconds. Streaming provides real-time feedback instead of hanging requests.
**Implementation:** Server-Sent Events (SSE) with event stream.

### 2. Multi-Agent Architecture
**Why:** Complex reasoning requires step-by-step analysis rather than single-pass inference.
**Implementation:** Strands agents framework with Claude for reasoning steps.

### 3. Single Docker Container
**Why:** Simpler deployment, cost-effective, no inter-service communication latency.
**Implementation:** Multi-stage Dockerfile builds frontend, backend serves both.

### 4. CORS Enabled
**Why:** Frontend and backend may be served from same origin but still need flexibility.
**Implementation:** CORSMiddleware with allow_origins=["*"].

## Data Flow

### Request Phase
1. User enters trend in frontend (e.g., "Oversized blazers with metallic accents")
2. Frontend sends POST to `/api/generate-skus`
3. Backend receives TrendRequest with validation (3-300 chars)

### Processing Phase
1. Agent worker thread spawns in background
2. `run_trend_agent()` executes multi-step reasoning
3. Steps pushed to queue for streaming

### Response Phase
1. Frontend receives SSE stream events
2. Displays progress: "Searching trends...", "Analyzing SKUs...", etc.
3. Final SKU recommendations displayed with reasoning

## Error Handling

- **Timeout (120s):** Agent takes too long → error event
- **API Failures:** Serper/Tavily down → graceful fallback
- **Invalid Input:** Trend < 3 chars or > 300 chars → validation error
- **Missing Frontend:** Falls back to index.html in frontend/ dir

## Performance Considerations

- **Build Cache:** Multi-stage Dockerfile layers frontend build separately
- **Health Checks:** App Runner monitors `/health` endpoint (30s intervals)
- **Streaming:** No request hanging, browser keeps connection open
- **Assets:** Vite builds optimized JS bundles with hashing
- **Python Dependencies:** Minimal requirements.txt for faster builds

## Scalability

| Metric | Current | Limit |
|--------|---------|-------|
| Concurrent Requests | 1 | Limited by App Runner instance |
| Timeout | 120s | Configurable |
| Memory | 2GB | Configurable via App Runner |
| CPU | 1024 CPU units | Configurable via App Runner |

**To scale:** Increase App Runner instance size or use multiple instances with load balancing.

## Security

- **Environment Variables:** Secrets via `.env` (not in repo)
- **CORS:** Allow all origins (can be restricted)
- **Input Validation:** Trend text length validation
- **Health Endpoint:** Public, no authentication required
- **API Key Storage:** AWS Secrets Manager (recommended for production)

## Monitoring & Logging

- **Health Endpoint:** `/health` returns service status
- **CloudWatch Logs:** App Runner auto-streams to CloudWatch
- **Error Tracking:** Errors logged to stdout (captured by App Runner)
- **Performance:** Monitor `/api/generate-skus` latency (typical: 30-60s)

## Future Enhancements

1. **Database Integration:** Store trend history and SKU recommendations
2. **Authentication:** User accounts and API keys
3. **Rate Limiting:** Prevent abuse
4. **Caching:** Cache trend analysis results
5. **Analytics:** Track popular trends and generated SKUs
6. **Batch Processing:** Handle multiple trends in single request
7. **Model Selection:** Support multiple Claude models
8. **Regional Deployment:** Multi-region with CDN for frontend
