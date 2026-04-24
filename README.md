# Trend-to-SKU Translator

An AI-powered system that converts fashion trends into actionable SKU (Stock Keeping Unit) recommendations using multi-agent reasoning with Claude AI.

## Features

- 🎯 **Intelligent Trend Analysis:** Uses Claude Sonnet 4 to analyze fashion trends
- 🔍 **Web Research:** Integrates Serper and Tavily APIs for current trend data
- 📊 **SKU Generation:** Automatically generates product variants and recommendations
- ⚡ **Real-time Streaming:** Stream progress updates as agent reasons through steps
- 🎨 **Interactive UI:** React-based frontend for easy trend input and SKU viewing
- 🐳 **Containerized:** Docker support for easy deployment
- ☁️ **Cloud Ready:** Deploy to AWS App Runner with one command

## Quick Start

### Prerequisites

- Python 3.11+
- Node.js 18+
- API Keys:
  - Claude API key (via AWS Bedrock)
  - Serper API key
  - Tavily API key

### Local Development

1. **Clone repository:**
```bash
git clone https://github.com/mohitparihar-geoiq/sku-trend-translator.git
cd sku-trend-translator
```

2. **Set up environment:**
```bash
cp .env.example .env
# Edit .env with your API keys
```

3. **Backend setup:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

4. **Frontend setup:**
```bash
cd frontend
npm install
npm run build
cd ..
```

5. **Run application:**
```bash
python api/server.py
```

Visit `http://localhost:8000` in your browser.

---

## AWS Deployment

### Option 1: One-Command Deploy (Recommended)

```bash
bash DEPLOY_NOW.sh
```

This script handles:
- Creating ECR repository
- Building Docker image
- Pushing to AWS
- Deploying to App Runner
- Retrieving service URL

### Option 2: Step-by-Step Deploy

1. **Push to ECR:**
```bash
bash CLOUDSHELL_PUSH.sh
```

2. **Deploy to App Runner:**
```bash
bash CLOUDSHELL_DEPLOY.sh
```

### Option 3: Manual CloudShell Deployment

Open AWS CloudShell and run:
```bash
git clone https://github.com/mohitparihar-geoiq/sku-trend-translator.git
cd sku-trend-translator
bash DEPLOY_NOW.sh
```

---

## Configuration

### Environment Variables

```env
# Required
SERPER_API_KEY=your_serper_key
TAVILY_API_KEY=your_tavily_key
BEDROCK_API_KEY=your_bedrock_key
BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20250929-v1:0

# AWS Credentials (for App Runner deployment)
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_DEFAULT_REGION=us-east-1
```

See `.env.example` for all available options.

---

## API Documentation

### Health Check

```bash
GET /health
```

Response:
```json
{
  "status": "alive",
  "service": "Trend-to-SKU Translator",
  "agent": "Strands + Claude Sonnet 4"
}
```

### Generate SKUs

```bash
POST /api/generate-skus
Content-Type: application/json

{
  "trend": "Oversized blazers with metallic accents"
}
```

**Response:** Server-Sent Events (SSE) stream

```
data: {"type": "step", "step": "Analyzing trend...", "progress": 10}
data: {"type": "step", "step": "Searching for similar products...", "progress": 30}
data: {"type": "result", "data": {"skus": [...], "reasoning": "..."}}
```

---

## Project Structure

```
sku-trend-translator/
├── api/
│   ├── server.py              # FastAPI application
│   └── __init__.py
├── agent/
│   ├── trend_agent.py         # AI agent logic
│   └── __init__.py
├── frontend/
│   ├── src/
│   │   ├── main.jsx           # React entry point
│   │   └── components/        # React components
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
├── Dockerfile                 # Multi-stage build
├── .dockerignore
├── .gitignore
├── requirements.txt           # Python dependencies
├── DEPLOY_NOW.sh             # Quick deployment script
├── CLOUDSHELL_DEPLOY.sh      # Complete deployment script
├── CLOUDSHELL_PUSH.sh        # Build and push to ECR
├── APPROACH.md               # Architecture details
└── README.md                 # This file
```

---

## Development

### Backend Development

```bash
source venv/bin/activate
pip install -r requirements.txt
python api/server.py
```

The server reloads automatically on file changes.

### Frontend Development

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173` (Vite dev server) or `http://localhost:8000` (through backend).

### Building Frontend

```bash
cd frontend
npm run build
```

Builds optimized frontend to `frontend/dist/`.

---

## Docker

### Build Locally

```bash
docker build -t sku-translator:latest .
```

### Run Locally

```bash
docker run -p 8000:8000 \
  -e SERPER_API_KEY=your_key \
  -e TAVILY_API_KEY=your_key \
  -e BEDROCK_API_KEY=your_key \
  sku-translator:latest
```

---

## Deployment Architecture

```
GitHub Repository
    ↓
AWS App Runner (Source)
    ↓ (detects Dockerfile)
Build Process
    ├─ Node.js: Build React frontend
    └─ Python: Install dependencies
    ↓
Docker Image
    ↓
Run on Port 8000
    ├─ FastAPI server
    ├─ Serves frontend at /
    └─ API at /api/generate-skus
    ↓
App Runner Service URL
    └─ https://your-app.region.awsapprunner.com
```

---

## Monitoring

### Health Check

App Runner performs health checks every 30 seconds:
```bash
GET /health
```

### Logs

View logs in AWS CloudWatch:
```bash
aws logs tail /aws/apprunner/trend-sku-translator/service_deployment --follow
```

### Metrics

Monitor in AWS CloudWatch:
- Request count
- Request latency
- Error rate
- CPU/Memory usage

---

## Troubleshooting

### Build fails with "No such file or directory"

**Issue:** Frontend dependencies not properly installed.
**Solution:** Delete `node_modules/` and `frontend/dist/`, rebuild Docker image.

### Service stuck in "RUNNING" state

**Issue:** Health check failing.
**Solution:** Check logs, ensure port 8000 is exposed, verify EXPOSE statement in Dockerfile.

### Agent timeout (120s)

**Issue:** Trend analysis taking too long.
**Solution:** Check API key quota, simplify trend description, verify connectivity.

### API Keys not working

**Issue:** Missing or incorrect environment variables.
**Solution:** Verify keys in `.env`, check AWS Secrets Manager if used.

---

## Performance

- **Typical Response Time:** 30-60 seconds per trend
- **Concurrent Requests:** Limited by App Runner instance size
- **Max Input:** 300 characters
- **Timeout:** 120 seconds

---

## Security

- ✅ Environment variables for secrets (not in repo)
- ✅ Input validation on trend text
- ✅ CORS enabled (can be restricted)
- ⚠️ Secrets in `.env` (use AWS Secrets Manager in production)

---

## Support

For issues or questions, check APPROACH.md or review deployment scripts.

---

## License

This project is provided as-is for internal use.
