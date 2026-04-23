# Trend-to-SKU Translator
**Lenskart Hackathon 2.0 | Problem #20 | Merchandising | 65 pts**

## Impact
- **Before:** 2 days manual research across Vogue, Pinterest, TikTok
- **After:** 3 minutes
- **Delta: 97% faster**

## Architecture
```
User Input → FastAPI → Strands Agent → search_fashion_trends (×2) → format_sku_output → JSON → UI Cards
```

## Setup (3 steps)
```bash
git clone <your-repo>
pip install -r requirements.txt
cp .env.example .env        # add your BEDROCK_API_KEY from AWS Bedrock Console → API Keys
python -m api.server        # open http://localhost:8000
```

## Agent Tools
| Tool | Purpose |
|------|---------|
| `search_fashion_trends` | Queries DuckDuckGo for live trend signals |
| `format_sku_output` | Validates and structures the final JSON |

## Business Impact
Before: 2-day manual buyer research | After: 3-minute AI synthesis | Delta: 97% faster TAT
