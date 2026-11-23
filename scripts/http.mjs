import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';

export function loopback(port) {
  assert.match(String(port), /^\d{1,5}$/);
  assert.ok(Number(port) >= 1 && Number(port) <= 65535);
  return 'http://127.0.0.1:' + port;
}

export async function request(url, status = 200, options = {}) {
  const response = await fetch(url, {
    ...options,
    redirect: 'manual',
    signal: AbortSignal.timeout(4_000),
  });
  assert.equal(response.status, status, 'Unexpected status for ' + new URL(url).pathname);
  return response;
}

export async function until(label, seconds, check) {
  const deadline = Date.now() + seconds * 1000;
  let error;
  do {
    try {
      await check();
      console.log(label + ' verified');
      return;
    } catch (failure) {
      error = failure;
      if (Date.now() < deadline) await delay(1000);
    }
  } while (Date.now() < deadline);
  throw new Error(label + ' failed: ' + error.message);
}
