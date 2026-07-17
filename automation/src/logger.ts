// Logger simple que nunca imprime secretos (tokens, claves, cookies).

const SECRET_PATTERN = /(key|token|secret|authorization|cookie)/i;

function redact(value: unknown): unknown {
  if (typeof value === "string") {
    // Oculta querystrings tipo ?api_key=xxxx o Authorization headers pegados en texto libre.
    return value.replace(/([?&](?:api_key|key|token)=)[^&\s]+/gi, "$1***");
  }
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = SECRET_PATTERN.test(k) ? "***" : redact(v);
    }
    return out;
  }
  return value;
}

function ts(): string {
  return new Date().toISOString();
}

export const logger = {
  info(msg: string, extra?: unknown) {
    console.log(`[${ts()}] INFO  ${msg}`, extra !== undefined ? redact(extra) : "");
  },
  warn(msg: string, extra?: unknown) {
    console.warn(`[${ts()}] WARN  ${msg}`, extra !== undefined ? redact(extra) : "");
  },
  error(msg: string, extra?: unknown) {
    console.error(`[${ts()}] ERROR ${msg}`, extra !== undefined ? redact(extra) : "");
  },
};
