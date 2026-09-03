// Infinite Ascension — secure log ingestion endpoint for Cloudflare Workers
// Required Worker secrets:
//   GITHUB_TOKEN  = fine-grained token with Contents: Read and write on this repo
//   GITHUB_REPO   = Mataiasu/Infinite-Ascension
//
// Deploy this Worker and configure LAUNCHER_LOG_ENDPOINT in the launcher.

const ALLOWED_ORIGIN = "*";
const MAX_BODY = 512 * 1024;

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors() });
    }

    // Safe health check: never exposes the GitHub token itself.
    if (request.method === "GET") {
      return json({
        ok: true,
        service: "Infinite Ascension log ingest",
        github_configured: Boolean(env.GITHUB_TOKEN),
        repository: env.GITHUB_REPO || "Mataiasu/Infinite-Ascension"
      });
    }

    if (request.method !== "POST") {
      return json({ error: "POST required" }, 405);
    }

    if (!env.GITHUB_TOKEN) {
      return json({ error: "GITHUB_TOKEN secret is not configured" }, 503);
    }

    const length = Number(request.headers.get("content-length") || 0);
    if (length > MAX_BODY) return json({ error: "payload too large" }, 413);

    let payload;
    try { payload = await request.json(); }
    catch { return json({ error: "invalid json" }, 400); }

    const log = typeof payload.log === "string" ? payload.log : "";
    if (!log || log.length > MAX_BODY) return json({ error: "invalid log" }, 400);

    const safeBuild = String(payload.build ?? "0").replace(/[^0-9]/g, "").slice(0, 12) || "0";
    const safeSession = String(payload.session ?? crypto.randomUUID()).replace(/[^a-zA-Z0-9_-]/g, "").slice(0, 64);
    const date = new Date().toISOString().replace(/[:.]/g, "-");
    const path = `logs/sessions/${date}_${safeBuild}_${safeSession}.log`;

    const repo = env.GITHUB_REPO || "Mataiasu/Infinite-Ascension";
    const url = `https://api.github.com/repos/${repo}/contents/${path}`;
    const body = btoa(unescape(encodeURIComponent(log)));

    const response = await fetch(url, {
      method: "PUT",
      headers: {
        "Authorization": `Bearer ${env.GITHUB_TOKEN}`,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "Infinite-Ascension-Log-Ingest",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        message: `logs: session ${safeSession} build ${safeBuild}`,
        content: body,
        branch: "main"
      })
    });

    if (!response.ok) {
      const detail = await response.text();
      return json({ error: "github upload failed", detail: detail.slice(0, 500) }, 502);
    }

    return json({ ok: true, path }, 201);
  }
};

function cors() {
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  };
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { "Content-Type": "application/json", ...cors() }
  });
}
