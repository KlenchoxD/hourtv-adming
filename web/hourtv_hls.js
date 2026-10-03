// Bundled HLS support, scoped by the Dart adapter to the HourTV HTTPS relay.
window.hourTvHlsSupported = () => typeof Hls !== 'undefined' && Hls.isSupported();
window.hourTvAttachHls = (video, url, onFatal) => {
  const hls = new Hls({enableWorker:true, backBufferLength:20});
  let failed = false;
  let recovered = 0;
  hls.on(Hls.Events.ERROR, (_, data) => {
    if (data.fatal && !failed) {
      if (data.type === Hls.ErrorTypes.MEDIA_ERROR && recovered++ < 2) {
        hls.recoverMediaError();
        return;
      }
      failed = true;
      onFatal(data.details || 'unknown');
    }
  });
  hls.attachMedia(video);
  hls.loadSource(url);
  return hls;
};
