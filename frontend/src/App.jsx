import { useEffect, useMemo, useRef, useState } from "react";

const EXAMPLES = [
  "Y2K transparent oval frames TikTok 2025",
  "K-drama soft girl earth tones tortoiseshell 2025",
  "Sabrina Carpenter cherry red oversized",
  "Brat summer oversized shield sunglasses"
];

const LOADING_MESSAGES = [
  "stalking Pinterest...",
  "watching TikTok...",
  "reading Vogue...",
  "checking K-drama stills...",
  "big brain time...",
  "generating alpha..."
];

const STEP_ICONS = {
  start: "🚀",
  model: "⚡",
  search: "🔍",
  found: "✅",
  think: "🧠",
  validate: "📋",
  success: "🎉",
  parse: "⚙️",
  done: "🌟",
  warn: "🔍",
  error: "🔴"
};

const COLOR_MAP = {
  black: "#111", white: "#fff", amber: "#FFBF00", honey: "#EB9605", tortoiseshell: "#8B4513",
  brown: "#6B3A2A", cream: "#FFFDD0", pink: "#FF69B4", rose: "#FF007F", red: "#E53935",
  cherry: "#D2042D", blue: "#2196F3", navy: "#001f5c", teal: "#009688", green: "#4CAF50",
  grey: "#9E9E9E", gray: "#9E9E9E", nude: "#E3BC9A", earth: "#8B6914", sage: "#9CAF88",
  olive: "#6B8E23", gold: "#FFD700", silver: "#C0C0C0", clear: "#e0e0e0", transparent: "#e0e0e0"
};

function colorHex(name) {
  const lower = String(name || "").toLowerCase();
  if (!lower) return "#888";
  for (const [k, v] of Object.entries(COLOR_MAP)) {
    if (lower.includes(k)) return v;
  }
  return "#888";
}

function statusClass(status) {
  if (status === "DROP READY") return "drop-ready";
  if (status === "TREND WATCH") return "trend-watch";
  return "too-early";
}

export default function App() {
  const [trendInput, setTrendInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [loadingIndex, setLoadingIndex] = useState(0);
  const [errorMsg, setErrorMsg] = useState("");
  const [logs, setLogs] = useState([]);
  const [result, setResult] = useState(null);
  const [startTs, setStartTs] = useState(0);
  const logContainerRef = useRef(null);

  const loadingMessage = useMemo(() => LOADING_MESSAGES[loadingIndex], [loadingIndex]);

  useEffect(() => {
    if (!loading) return;
    const id = setInterval(() => {
      setLoadingIndex((v) => (v + 1) % LOADING_MESSAGES.length);
    }, 2000);
    return () => clearInterval(id);
  }, [loading]);

  useEffect(() => {
    if (logContainerRef.current) {
      logContainerRef.current.scrollTop = logContainerRef.current.scrollHeight;
    }
  }, [logs]);

  const resetResultsOnly = () => {
    setErrorMsg("");
    setLogs([]);
    setResult(null);
    setStartTs(0);
  };

  const resetAll = () => {
    resetResultsOnly();
    setTrendInput("");
    setLoading(false);
    setLoadingIndex(0);
  };

  const exportCsv = () => {
    if (!result?.skus?.length) return;
    const fields = [
      "sku_name", "vibe_tag", "frame_style", "frame_material", "primary_color", "secondary_color",
      "lens_type", "lens_color", "target_segment", "price_band_inr", "trend_score",
      "trend_status", "inspired_by", "vendor_notes"
    ];
    const header = fields.join(",");
    const rows = result.skus.map((sku) =>
      fields
        .map((f) => {
          let v = String(sku[f] ?? "");
          if (v.includes(",") || v.includes('"') || v.includes("\n")) v = `"${v.replace(/"/g, '""')}"`;
          return v;
        })
        .join(",")
    );
    const csv = [header, ...rows].join("\n");
    const blob = new Blob([csv], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `lenskart_sku_specs_${Date.now()}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const addLog = (step) => {
    setLogs((prev) => [...prev, step]);
  };

  const readSseStream = async (response) => {
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const events = buffer.split("\n\n");
      buffer = events.pop() || "";

      for (const rawEvent of events) {
        const line = rawEvent
          .split("\n")
          .find((entry) => entry.startsWith("data: "));
        if (!line) continue;
        const payload = line.slice(6).trim();
        if (!payload) continue;

        let evt;
        try {
          evt = JSON.parse(payload);
        } catch {
          continue;
        }

        if (evt.type === "step") {
          setStartTs((prev) => prev || evt.ts || 0);
          addLog(evt);
        } else if (evt.type === "result") {
          setResult(evt.data);
          setLoading(false);
        } else if (evt.type === "error") {
          addLog({ icon: "error", title: evt.title || "Error", detail: evt.detail || "Unknown error", ts: Date.now() / 1000 });
          setErrorMsg(evt.detail || "Agent failed");
          setLoading(false);
        }
      }
    }
  };

  const generate = async (seedInput) => {
    const value = (seedInput ?? trendInput).trim();
    if (value.length < 3) return;

    setTrendInput(value);
    setLoading(true);
    setLoadingIndex(0);
    resetResultsOnly();

    try {
      const response = await fetch("/api/generate-skus", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ trend: value })
      });

      if (!response.ok) {
        const err = await response.json().catch(() => ({ detail: "Server error" }));
        throw new Error(err.detail || "Request failed");
      }

      await readSseStream(response);
    } catch (error) {
      setLoading(false);
      setErrorMsg(error.message || "Failed to generate SKUs");
    }
  };

  return (
    <div className="container">
      <div className="header">
        <div className="logo">TREND RADAR 🔭</div>
        <div className="subtitle">Lenskart Merchandising Intelligence · Powered by Strands Agent</div>
        <div className="live-badge">⚡ LIVE TREND ANALYSIS</div>
      </div>

      <div className="input-section">
        <div className="input-row">
          <input
            type="text"
            className="trend-input"
            placeholder="#Y2K, #K-drama soft girl, #Brat Summer, #Jimin-core..."
            maxLength={300}
            value={trendInput}
            onChange={(e) => setTrendInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && generate()}
          />
          <button className="generate-btn" disabled={loading} onClick={() => generate()}>
            GENERATE →
          </button>
        </div>
        <div className="pills">
          {EXAMPLES.map((text) => (
            <button key={text} className="pill" onClick={() => generate(text)}>
              {text}
            </button>
          ))}
        </div>
      </div>

      {loading && (
        <div className="loading active">
          <div className="orb-wrap"><div className="orb" /></div>
          <div className="loading-msg">{loadingMessage}</div>
        </div>
      )}

      {logs.length > 0 && (
        <div className="agent-log active">
          <div className="agent-log-header">
            <span className={`dot ${loading ? "active" : ""}`} />
            AGENT ACTIVITY LOG
          </div>
          <div className="log-entries" ref={logContainerRef}>
            {logs.map((step, idx) => (
              <div className={`log-entry step-${step.icon || "start"}`} key={`${step.title}-${idx}`}>
                <span className="log-icon">{STEP_ICONS[step.icon] || "•"}</span>
                <div className="log-content">
                  <div className="log-title">{step.title}</div>
                  {step.detail ? <div className="log-detail">{step.detail}</div> : null}
                </div>
                <span className="log-time">
                  {step.ts && startTs ? `${Math.max(step.ts - startTs, 0).toFixed(1)}s` : ""}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {errorMsg && (
        <div className="error-card active">
          <div className="emoji">💀</div>
          <div className="title">VIBES NOT FOUND</div>
          <div className="msg">{errorMsg}</div>
        </div>
      )}

      {result && !errorMsg && (
        <>
          <div className="impact-banner active">
            <div className="impact-stat"><div className="label">Before</div><div className="value red">2 DAYS</div></div>
            <div className="impact-divider" />
            <div className="impact-stat"><div className="label">After</div><div className="value grn">3 MIN</div></div>
            <div className="impact-divider" />
            <div className="impact-stat"><div className="label">Delta</div><div className="value gld">97% FASTER</div></div>
          </div>

          {result.trend_summary && (
            <div className="trend-summary active">
              <div className="label"><span className="live-dot" />📡 LIVE TREND INTEL</div>
              <div className="text">{result.trend_summary}</div>
              {result.search_queries_used?.length ? (
                <div className="query-pills">
                  {result.search_queries_used.map((q, idx) => (
                    <span className="query-pill" key={`${q}-${idx}`}>🔍 {q}</span>
                  ))}
                </div>
              ) : null}
            </div>
          )}

          <div className="sku-grid">
            {(result.skus || []).map((sku, i) => (
              <div
                className="sku-card visible"
                style={{
                  transitionDelay: `${i * 120}ms`,
                  borderTop: `2px solid ${{
                    "DROP READY": "var(--neon-green)",
                    "TREND WATCH": "var(--neon-gold)",
                    "TOO EARLY": "var(--neon-pink)"
                  }[sku.trend_status] || "var(--neon-pink)"}`
                }}
                key={`${sku.sku_name}-${i}`}
              >
                <div
                  className="card-color-banner"
                  style={{
                    background: `linear-gradient(135deg, ${colorHex(sku.primary_color)} 0%, ${colorHex(sku.secondary_color)} 100%)`
                  }}
                >
                  <span className="card-number">0{i + 1}</span>
                  <div className="card-color-banner-inner">
                    <span className="card-color-name">{sku.primary_color}</span>
                    <span className="card-color-season">SS25</span>
                  </div>
                </div>
                <div className="sku-header">
                  <div className="sku-name">
                    {sku.sku_name}
                    <span className={`status-badge ${statusClass(sku.trend_status)}`}>{sku.trend_status}</span>
                  </div>
                  <div className="vibe-tag">{sku.vibe_tag}</div>
                </div>
                <div className="sku-body">
                  <div className="spec-row"><span className="spec-label">Frame Style</span><span className="spec-value">{sku.frame_style}</span></div>
                  <div className="spec-row"><span className="spec-label">Material</span><span className="spec-value">{sku.frame_material}</span></div>
                  <div className="spec-row">
                    <span className="spec-label">Colors</span>
                    <span className="spec-value color-swatches">
                      <span className="swatch" style={{ background: colorHex(sku.primary_color) }} title={sku.primary_color} />
                      <span className="swatch" style={{ background: colorHex(sku.secondary_color) }} title={sku.secondary_color} />
                    </span>
                  </div>
                  <div className="spec-row"><span className="spec-label">Lens</span><span className="spec-value">{sku.lens_type} · {sku.lens_color}</span></div>
                  <div className="spec-row"><span className="spec-label">Target</span><span className="spec-value">{sku.target_segment}</span></div>
                  <div className="spec-row"><span className="spec-label">Price Band</span><span className="spec-value"><span className="price-pill">{sku.price_band_inr}</span></span></div>
                </div>
                <div className="score-section">
                  <div className="score-label"><span>TREND SCORE</span><span>{sku.trend_score}</span></div>
                  <div className="score-bar-bg"><div className="score-bar-fill" style={{ width: `${sku.trend_score}%` }} /></div>
                </div>
                <div className="inspired-section">
                  <div className="inspired-label">Inspired By</div>
                  <div className="inspired-text">{sku.inspired_by}</div>
                </div>
                <div className="vendor-notes">{sku.vendor_notes}</div>
              </div>
            ))}
          </div>

          <div className="action-bar active">
            <button className="export-btn" onClick={exportCsv}>⬇ Export as CSV for Vendor</button>
            <button className="new-btn" onClick={resetAll}>↩ New Trend</button>
          </div>
        </>
      )}
    </div>
  );
}
