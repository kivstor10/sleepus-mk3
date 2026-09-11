const allowedOrigins = new Set([
  "https://sleepus.dev",
  "https://www.sleepus.dev",
  "http://localhost:8765"
]);

function corsHeaders(origin) {
  return {
    "Access-Control-Allow-Origin": allowedOrigins.has(origin) ? origin : "https://sleepus.dev",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin"
  };
}

function json(body, status, origin) {
  return Response.json(body, { status, headers: corsHeaders(origin) });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    if (url.pathname !== "/api/waitlist" || request.method !== "POST") {
      return json({ error: "Not found." }, 404, origin);
    }

    if (!allowedOrigins.has(origin)) {
      return json({ error: "Origin not allowed." }, 403, origin);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "Email is required." }, 400, origin);
    }

    const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
      return json({ error: "Enter a valid email address." }, 400, origin);
    }

    await env.DB.prepare("INSERT OR IGNORE INTO waitlist_signups (email) VALUES (?)")
      .bind(email)
      .run();

    return json({ ok: true }, 201, origin);
  }
};