// Puppeteer browser singleton intentionally disabled in the Vercel HTTP adapter.
async function getBrowser() {
  throw new Error("Puppeteer disabled in serverless HTTP runtime");
}

module.exports = { getBrowser };
