(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory;
  else root.HourTVSupabaseRestAuth = factory;
})(typeof window !== 'undefined' ? window : globalThis, function createRestSupabaseClient(options) {
  options = options || {};
  var url = String(options.url || '').replace(/\/$/, '');
  var key = options.key || '';
  var storage = options.storage || (typeof localStorage !== 'undefined' ? localStorage : null);
  var fetchImpl = options.fetch || (typeof fetch !== 'undefined' ? fetch : null);
  var onSessionExpired = options.onSessionExpired || function () {};
  var accessKey = options.accessKey || 'hourtv_sb_access_token';
  var refreshKey = options.refreshKey || 'hourtv_sb_refresh_token';
  var expiresKey = options.expiresKey || 'hourtv_sb_expires_at';
  var refreshPromise = null;
  var skewMs = Number(options.refreshSkewMs || 60000);

  function read(keyName) { return storage && storage.getItem(keyName); }
  function write(keyName, value) {
    if (!storage) return;
    if (value === undefined || value === null || value === '') storage.removeItem(keyName);
    else storage.setItem(keyName, String(value));
  }
  function session() {
    var access = read(accessKey);
    if (!access) return null;
    var expiresAt = Number(read(expiresKey) || 0);
    return { access_token: access, refresh_token: read(refreshKey) || undefined, expires_at: expiresAt || undefined, user: { email: 'Administrador' } };
  }
  function saveSession(value) {
    if (!value || !value.access_token) return;
    write(accessKey, value.access_token);
    write(refreshKey, value.refresh_token);
    var expiresAt = value.expires_at;
    if (!expiresAt && value.expires_in) expiresAt = Math.floor(Date.now() / 1000) + Number(value.expires_in);
    write(expiresKey, expiresAt);
  }
  function clearSession() {
    write(accessKey, null);
    write(refreshKey, null);
    write(expiresKey, null);
  }
  function jsonResponse(response) {
    return response.text().then(function (text) {
      var data = null;
      if (text) { try { data = JSON.parse(text); } catch (_) { data = text; } }
      return { response: response, data: data };
    });
  }
  function expiredSoon() {
    var expiresAt = Number(read(expiresKey) || 0);
    return expiresAt > 0 && expiresAt * 1000 <= Date.now() + skewMs;
  }
  function refreshSession() {
    if (refreshPromise) return refreshPromise;
    var refreshToken = read(refreshKey);
    if (!refreshToken) {
      clearSession();
      onSessionExpired();
      return Promise.reject(new Error('No hay refresh token'));
    }
    refreshPromise = fetchImpl(url + '/auth/v1/token?grant_type=refresh_token', {
      method: 'POST',
      headers: { apikey: key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refreshToken })
    }).then(jsonResponse).then(function (result) {
      if (!result.response.ok || !result.data || !result.data.access_token) throw new Error('No se pudo renovar la sesión');
      saveSession(result.data);
      return session();
    }).catch(function (error) {
      clearSession();
      onSessionExpired();
      throw error;
    }).finally(function () { refreshPromise = null; });
    return refreshPromise;
  }
  function ensureValidSession() {
    if (expiredSoon()) return refreshSession();
    return Promise.resolve(session());
  }
  function request(requestFactory, retried) {
    return ensureValidSession().catch(function (error) {
      if (!read(accessKey)) return Promise.reject(error);
      return Promise.reject(error);
    }).then(function () {
      return requestFactory(read(accessKey));
    }).then(function (result) {
      if (result.response && result.response.status === 401 && !retried) {
        return refreshSession().then(function () { return request(requestFactory, true); });
      }
      return result;
    });
  }
  function authError(data) {
    return new Error((data && (data.error_description || data.msg || data.message)) || 'Supabase HTTP error');
  }
  var client = {
    auth: {
      getSession: function () { return Promise.resolve({ data: { session: session() } }); },
      onAuthStateChange: function () { return Promise.resolve({ data: { subscription: { unsubscribe: function () {} } } }); },
      signInWithPassword: function (credentials) {
        return fetchImpl(url + '/auth/v1/token?grant_type=password', {
          method: 'POST',
          headers: { apikey: key, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: credentials.email, password: credentials.password })
        }).then(jsonResponse).then(function (result) {
          if (!result.response.ok || !result.data || !result.data.access_token) return { data: null, error: authError(result.data) };
          saveSession(result.data);
          return { data: { session: Object.assign(session(), { user: { email: credentials.email } }) }, error: null };
        });
      },
      signInWithOAuth: function () { return Promise.resolve({ error: new Error('Usa el botón Continuar con Google') }); },
      signOut: function () { clearSession(); return Promise.resolve({ error: null }); },
      refreshSession: refreshSession
    },
    _clearSession: clearSession,
    _saveSession: saveSession,
    _refreshSession: refreshSession,
    _session: session,
    rpc: function (name, args) {
      return request(function (token) {
        return fetchImpl(url + '/rest/v1/rpc/' + encodeURIComponent(name), {
          method: 'POST',
          headers: { apikey: key, Authorization: token ? 'Bearer ' + token : 'Bearer ' + key, 'Content-Type': 'application/json' },
          body: JSON.stringify(args || {})
        }).then(jsonResponse);
      }).then(function (result) {
        return { data: result.data, error: result.response.ok ? null : authError(result.data) };
      });
    },
    from: function (table) {
      var params = new URLSearchParams(), head = false, countExact = false, method = 'GET', body, returnSingle = false;
      var query = {
        select: function (columns, opts) { params.set('select', columns || '*'); head = !!(opts && opts.head); countExact = !!(opts && opts.count); return query; },
        insert: function (values) { method = 'POST'; body = values; return query; },
        update: function (values) { method = 'PATCH'; body = values; return query; },
        delete: function () { method = 'DELETE'; return query; },
        single: function () { returnSingle = true; return query; },
        eq: function (column, value) { params.set(column, 'eq.' + value); return query; },
        neq: function (column, value) { params.set(column, 'neq.' + value); return query; },
        or: function (value) { params.set('or', '(' + value + ')'); return query; },
        range: function (from, to) { query._range = from + '-' + to; return query; },
        order: function (column, opts) { params.set('order', column + '.' + ((opts && opts.ascending === false) ? 'desc' : 'asc')); return query; },
        then: function (resolve, reject) {
          return request(function (token) {
            var headers = { apikey: key, Authorization: token ? 'Bearer ' + token : 'Bearer ' + key };
            if (query._range) headers.Range = query._range;
            if (body !== undefined) { headers['Content-Type'] = 'application/json'; headers.Prefer = 'return=representation'; }
            if (countExact) headers.Prefer = headers.Prefer ? headers.Prefer + ',count=exact' : 'count=exact';
            if (returnSingle) headers.Accept = 'application/vnd.pgrst.object+json';
            return fetchImpl(url + '/rest/v1/' + table + '?' + params.toString(), { method: head ? 'HEAD' : method, headers: headers, body: body === undefined ? undefined : JSON.stringify(body) }).then(function (response) {
              return jsonResponse(response).then(function (result) {
                var range = response.headers && response.headers.get ? (response.headers.get('content-range') || '') : '';
                var match = range.match(/\/(\d+)$/), data = result.data;
                if (returnSingle && Array.isArray(data)) data = data[0] || null;
                return { response: response, data: data, count: match ? Number(match[1]) : null };
              });
            });
          }).then(function (result) {
            return { data: result.data, error: result.response.ok ? null : authError(result.data), count: result.count };
          }).then(resolve, reject);
        }
      };
      return query;
    }
  };
  return client;
});
