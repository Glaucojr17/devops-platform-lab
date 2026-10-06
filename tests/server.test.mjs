import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createServer } from '../src/server.mjs';

test('health, metrics, request IDs and drain behavior', async () => {
  const logs = [];
  const app = createServer({ logger: line => logs.push(JSON.parse(line)) });
  app.server.listen(0, '127.0.0.1');
  await once(app.server, 'listening');
  const base = `http://127.0.0.1:${app.server.address().port}`;
  try {
    let response = await fetch(`${base}/health/live`, { headers: { 'x-request-id': 'trace-123' } });
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('x-request-id'), 'trace-123');
    assert.deepEqual(await response.json(), { status: 'alive' });
    response = await fetch(`${base}/health/ready`);
    assert.equal(response.status, 200);
    app.drain();
    response = await fetch(`${base}/health/ready`);
    assert.equal(response.status, 503);
    response = await fetch(`${base}/metrics`);
    assert.match(await response.text(), /lab_http_requests_total 4\n/);
    assert.equal(app.getRequestCount(), 4);
    assert.equal(logs.length, 4);
    assert.equal(logs[0].requestId, 'trace-123');
    assert.equal(logs[2].status, 503);
  } finally {
    app.server.close();
    await once(app.server, 'close');
  }
});

test('unknown route and unsupported method return explicit errors', async () => {
  const { server } = createServer({ logger: () => {} });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await fetch(`${base}/missing`)).status, 404);
    const response = await fetch(`${base}/`, { method: 'POST' });
    assert.equal(response.status, 405);
    assert.equal(response.headers.get('allow'), 'GET');
  } finally {
    server.close();
    await once(server, 'close');
  }
});
