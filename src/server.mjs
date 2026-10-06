import http from 'node:http';
import { randomUUID } from 'node:crypto';

const DEFAULT_PORT = 3000;

export function createServer({ logger = console.log } = {}) {
  let ready = true;
  let requests = 0;
  const server = http.createServer((request, response) => {
    const started = performance.now();
    const requestId = request.headers['x-request-id'] || randomUUID();
    const path = new URL(request.url, 'http://localhost').pathname;
    let status = 200;
    let body;
    let contentType = 'application/json; charset=utf-8';

    if (request.method !== 'GET') {
      status = 405;
      body = JSON.stringify({ error: 'method_not_allowed' });
      response.setHeader('Allow', 'GET');
    } else if (path === '/health/live') {
      body = JSON.stringify({ status: 'alive' });
    } else if (path === '/health/ready') {
      status = ready ? 200 : 503;
      body = JSON.stringify({ status: ready ? 'ready' : 'draining' });
    } else if (path === '/metrics') {
      contentType = 'text/plain; version=0.0.4; charset=utf-8';
      body = '# HELP lab_http_requests_total Total HTTP requests handled.\n# TYPE lab_http_requests_total counter\nlab_http_requests_total ' + (requests + 1) + '\n';
    } else if (path === '/') {
      body = JSON.stringify({ service: 'devops-platform-lab', status: 'ok' });
    } else {
      status = 404;
      body = JSON.stringify({ error: 'not_found' });
    }

    requests += 1;
    response.writeHead(status, {
      'Content-Type': contentType,
      'Content-Length': Buffer.byteLength(body),
      'X-Request-Id': String(requestId),
      'Cache-Control': 'no-store'
    });
    response.end(body);
    logger(JSON.stringify({ timestamp: new Date().toISOString(), level: 'info', event: 'http_request', requestId, method: request.method, path, status, durationMs: Math.round(performance.now() - started) }));
  });
  return { server, drain: () => { ready = false; }, getRequestCount: () => requests };
}

if (process.argv[1] && import.meta.url === new URL(`file://${process.argv[1]}`).href) {
  const { server, drain } = createServer();
  const port = Number.parseInt(process.env.PORT ?? String(DEFAULT_PORT), 10);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error('PORT must be an integer from 1 to 65535');
    process.exit(1);
  }
  server.listen(port, '0.0.0.0', () => console.log(JSON.stringify({ event: 'listening', port })));
  const shutdown = () => {
    drain();
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}
