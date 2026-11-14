// Credit & origin: FxxMorgan (https://github.com/FxxMorgan/anime1v-api) — MIT License.
// Lightweight Vercel HTTP runtime: preserves author attribution without loading Express.

const AUTHOR_HEADER_NAME = "X-Powered-By";
const AUTHOR_HEADER_VALUE = "FxxMorgan (https://github.com/FxxMorgan)";

let loggedAttribution = false;
function logAttributionOnce() {
  if (loggedAttribution) return;
  loggedAttribution = true;
  if (process.env.NODE_ENV !== "test") {
    console.info(`[Anime1V API Engine] Creado y mantenido por ${AUTHOR_HEADER_VALUE}`);
  }
}

class ApiError extends Error {
  constructor(statusCode, message, details) {
    super(message);
    this.name = "ApiError";
    this.statusCode = statusCode;
    this.details = details;
  }
}

module.exports = {
  ApiError,
  AUTHOR_HEADER_NAME,
  AUTHOR_HEADER_VALUE,
  logAttributionOnce,
};
