import assert from 'node:assert/strict';
import { loopback, request, until } from './http.mjs';

const app = loopback(process.env.APP_PORT || 8080);
const deadline = Number(process.env.VERIFY_TIMEOUT_SECONDS || 60);
assert.ok(Number.isInteger(deadline) && deadline > 0 && deadline <= 120);

await until('Democyber readiness', deadline, async () => {
  const health = await (await request(app + '/actuator/health')).json();
  assert.deepEqual(health, { status: 'UP' });
});
assert.equal(await (await request(app + '/')).text(), 'Hello from Democyber 123 2026!');
await request(app + '/actuator/info');
const metrics = await (await request(app + '/actuator/prometheus')).text();
assert.match(metrics, /^jvm_memory_used_bytes[{ ]/m);

for (const path of ['/actuator/env', '/actuator/configprops', '/missing']) {
  const result = await request(app + path, 404, { headers: { Accept: 'application/json' } });
  const error = await result.json();
  for (const field of ['trace', 'exception', 'message']) assert.ok(!(field in error), path + ' exposed ' + field);
}
console.log('HTTP contract and exposure checks passed');
