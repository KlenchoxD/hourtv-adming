// Binary yt-dlp is unavailable in serverless HTTP runtime.
module.exports = {
  isAvailable: false,
  extractWithYtdlp: async () => null,
};
