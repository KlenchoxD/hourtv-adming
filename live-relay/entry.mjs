import {connect} from 'cloudflare:sockets';
import relay from './worker.mjs';
import {socketHttp} from './socket-http.mjs';

export default {
  fetch(request, env, ctx) {
    // Cloudflare fetch cannot reach literal IP origins, and some IPTV origins
    // use nonstandard HTTP ports. The relay validates each host before this.
    return relay.fetch(request, env, ctx, (url, options) => url.protocol === 'http:'
      ? socketHttp(url, options, connect)
      : fetch(url, options));
  }
};
