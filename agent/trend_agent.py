import json
import re
import httpx
import time
import queue
from strands import Agent, tool
from strands.models import BedrockModel
from dotenv import load_dotenv
import os

load_dotenv()

# Module-level queue for streaming steps to the API layer
_step_queue: queue.Queue | None = None


def _emit_step(icon: str, title: str, detail: str = "", data: str = ""):
    """Push a step event to the current queue if active."""
    if _step_queue is not None:
        _step_queue.put({
            "type": "step",
            "icon": icon,
            "title": title,
            "detail": detail,
            "data": data,
            "ts": time.time(),
        })


@tool
def search_fashion_trends(query: str) -> str:
    """Search the web for current fashion trend information related to eyewear and glasses.
    Use this to find real trend signals from social media, celebrities, and fashion publications.
    Always search at least twice with different queries before generating SKUs.

    Args:
        query: Search query e.g. 'Y2K oval sunglasses trend 2025' or 'K-drama soft girl glasses aesthetic'

    Returns:
        Text with search results about the trend
    """
    _emit_step("search", f"Searching: \"{query}\"", "Querying DuckDuckGo for live trend signals...")
    try:
        encoded = httpx.URL("https://api.duckduckgo.com/").copy_with(
            params={"q": query, "format": "json", "no_html": "1", "skip_disambig": "1"}
        )
        response = httpx.get(str(encoded), timeout=10, follow_redirects=True)
        data = response.json()

        results = []
        if data.get("AbstractText"):
            results.append(f"Summary: {data['AbstractText']}")
        for topic in data.get("RelatedTopics", [])[:6]:
            if isinstance(topic, dict) and topic.get("Text"):
                results.append(topic["Text"])

        if not results:
            _emit_step("warn", f"No direct results for \"{query}\"", "Agent will use fashion knowledge instead")
            return f"No direct results found for '{query}'. Use your knowledge of current fashion trends for this query."

        snippets = [r[:120] + "..." if len(r) > 120 else r for r in results[:3]]
        _emit_step("found", f"Found {len(results)} results for \"{query}\"", "; ".join(snippets))
        return f"Search results for '{query}':\n\n" + "\n\n".join(results)

    except Exception as e:
        _emit_step("warn", f"Search failed for \"{query}\"", str(e)[:100])
        return f"Search temporarily unavailable ({str(e)}). Use your fashion knowledge to generate realistic trend-based SKUs."


@tool
def format_sku_output(skus_json: str) -> str:
    """Validate and return the final SKU JSON. Always call this as your LAST step
    before finishing. Pass your complete JSON string here.

    Args:
        skus_json: The complete JSON string with trend_summary, search_queries_used, and skus array

    Returns:
        Validated JSON string or error message describing what to fix
    """
    _emit_step("validate", "Validating SKU specs", "Checking all 14 fields across 3 SKUs...")
    try:
        clean = skus_json.replace("```json", "").replace("```", "").strip()
        data = json.loads(clean)

        errors = []
        if "trend_summary" not in data:
            errors.append("Missing 'trend_summary' field")
        if "skus" not in data:
            errors.append("Missing 'skus' field")
        elif not isinstance(data["skus"], list):
            errors.append("'skus' must be an array")
        elif len(data["skus"]) != 3:
            errors.append(f"Need exactly 3 SKUs, got {len(data['skus'])}")
        else:
            required_sku_fields = [
                "sku_name", "vibe_tag", "frame_style", "frame_material",
                "primary_color", "secondary_color", "lens_type", "lens_color",
                "target_segment", "price_band_inr", "trend_score",
                "trend_status", "inspired_by", "vendor_notes"
            ]
            for i, sku in enumerate(data["skus"]):
                missing = [f for f in required_sku_fields if f not in sku]
                if missing:
                    errors.append(f"SKU {i+1} missing fields: {missing}")
                if sku.get("trend_status") not in ["DROP READY", "TREND WATCH", "TOO EARLY"]:
                    errors.append(f"SKU {i+1}: trend_status must be DROP READY, TREND WATCH, or TOO EARLY")

        if errors:
            _emit_step("error", "Validation failed", "; ".join(errors))
            return f"Validation failed. Fix these issues and call format_sku_output again:\n" + "\n".join(f"- {e}" for e in errors)

        sku_names = [s.get("sku_name", "?") for s in data["skus"]]
        _emit_step("success", "All 3 SKUs validated", f"{sku_names[0]} | {sku_names[1]} | {sku_names[2]}")
        return json.dumps(data, ensure_ascii=False, indent=2)

    except json.JSONDecodeError as e:
        _emit_step("error", "Invalid JSON from agent", str(e)[:80])
        return f"Invalid JSON: {str(e)}. Fix the JSON syntax and call format_sku_output again."


def create_agent() -> Agent:
    from agent.prompts import SYSTEM_PROMPT

    model = BedrockModel(
        model_id="us.anthropic.claude-sonnet-4-20250514-v1:0",
        region_name=os.environ.get("AWS_DEFAULT_REGION", "ap-south-1"),
    )

    return Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        tools=[search_fashion_trends, format_sku_output],
    )


def run_trend_agent(trend_input: str, step_queue: queue.Queue | None = None) -> dict:
    """Run the Strands trend agent and return parsed SKU data dict."""
    global _step_queue
    _step_queue = step_queue

    _emit_step("start", "Agent initialized", f"Analyzing trend: \"{trend_input}\"")
    _emit_step("model", "Connected to Claude Sonnet 4 via AWS Bedrock", f"Region: {os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')}")

    agent = create_agent()

    prompt = f"""Analyze this fashion trend and generate 3 Lenskart SKU specs.

TREND INPUT: {trend_input}

Steps you MUST follow:
1. Call search_fashion_trends with "{trend_input} eyewear 2025"
2. Call search_fashion_trends with "{trend_input} glasses fashion trend"
3. Synthesize findings into 3 SKU specs covering the full JSON format
4. Call format_sku_output with your complete JSON
5. Return ONLY the exact JSON string that format_sku_output returned"""

    _emit_step("think", "Agent is thinking", "Planning search strategy and analyzing trend signals...")

    response = agent(prompt)
    response_text = str(response)

    _emit_step("parse", "Parsing agent response", "Extracting structured JSON from agent output...")

    # Try multiple extraction strategies
    json_match = re.search(r'\{[\s\S]*\}', response_text)
    if json_match:
        try:
            result = json.loads(json_match.group())
            _emit_step("done", "SKU generation complete", f"{len(result.get('skus', []))} vendor-ready specs generated")
            _step_queue = None
            return result
        except json.JSONDecodeError:
            pass

    clean = response_text.replace("```json", "").replace("```", "").strip()
    try:
        result = json.loads(clean)
        _emit_step("done", "SKU generation complete", f"{len(result.get('skus', []))} vendor-ready specs generated")
        _step_queue = None
        return result
    except json.JSONDecodeError:
        pass

    all_matches = list(re.finditer(r'\{[\s\S]*?\}(?=\s*$|\s*\n\s*[A-Z])', response_text))
    if all_matches:
        try:
            result = json.loads(all_matches[-1].group())
            _emit_step("done", "SKU generation complete", f"{len(result.get('skus', []))} specs generated")
            _step_queue = None
            return result
        except json.JSONDecodeError:
            pass

    _emit_step("error", "Failed to parse response", response_text[:150])
    _step_queue = None
    return {
        "error": True,
        "message": "Agent returned a response but JSON could not be parsed. Check agent logs.",
        "raw_preview": response_text[:300]
    }
