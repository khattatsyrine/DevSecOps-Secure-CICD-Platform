import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { loopback, request, until } from './http.mjs';

const prometheus = loopback(process.env.PROMETHEUS_PORT || 9090);
const grafana = loopback(process.env.GRAFANA_PORT || 3000);
const alertmanager = loopback(process.env.ALERTMANAGER_PORT || 9093);
const job = '{job="democyber"}';
const project = process.env.COMPOSE_PROJECT_NAME;
const timeout = Number(process.env.VERIFY_TIMEOUT_SECONDS || 70);
assert.ok(Number.isInteger(timeout) && timeout > 0 && timeout <= 120);

async function query(expression) {
  const response = await request(prometheus + '/api/v1/query?query=' + encodeURIComponent(expression));
  const data = await response.json();
  assert.equal(data.status, 'success');
  return data.data.result;
}

switch (process.argv[2]) {
  case 'metrics': {
    assert.ok(process.env.GRAFANA_ADMIN_PASSWORD, 'Grafana password is required');
    const auth = 'Basic ' + Buffer.from('admin:' + process.env.GRAFANA_ADMIN_PASSWORD).toString('base64');
    const options = { headers: { Authorization: auth } };
    await until('Prometheus target and HTTP/JVM metrics', timeout, async () => {
      const targets = await (await request(prometheus + '/api/v1/targets')).json();
      assert.ok(targets.data.activeTargets.some(target =>
        target.labels.job === 'democyber' && target.health === 'up' &&
        target.scrapeUrl === 'http://app:8080/actuator/prometheus'));
      for (const metric of ['http_server_requests_seconds_count', 'jvm_memory_used_bytes']) {
        assert.ok((await query(metric + job)).some(entry => Number(entry.value[1]) > 0), metric);
      }
    });
    await until('Grafana dashboard and datasource query', timeout, async () => {
      const dashboard = await (await request(grafana + '/api/dashboards/uid/democyber', 200, options)).json();
      assert.equal(dashboard.dashboard.uid, 'democyber');
      assert.ok(dashboard.dashboard.panels.every(panel => panel.datasource.uid === 'prometheus'));
      const proxied = await request(grafana + '/api/datasources/proxy/uid/prometheus/api/v1/query?query=' +
        encodeURIComponent('up' + job), 200, options);
      assert.ok((await proxied.json()).data.result.some(entry => entry.value[1] === '1'));
    });
    break;
  }
  case 'alert': {
    assert.match(project || '', /^[a-z0-9][a-z0-9_-]*$/);
    await until('Prometheus firing rule and Alertmanager receipt', timeout, async () => {
      assert.ok((await query('ALERTS{alertname="DemocyberDown",alertstate="firing"}')).length);
      const alerts = await (await request(alertmanager + '/api/v2/alerts')).json();
      assert.ok(alerts.some(alert => alert.labels.alertname === 'DemocyberDown' && alert.status.state === 'active'));
    });
    await until('Delivered Alertmanager webhook', timeout, () => {
      const json = execFileSync('docker', ['compose', '-p', project, 'exec', '-T', 'receiver',
        'node', '-e', "fetch('http://127.0.0.1:8080/alerts').then(r => { if (!r.ok) throw Error(r.status); return r.text(); }).then(console.log)"],
        { encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'pipe'] });
      assert.ok(JSON.parse(json).some(alert => alert.name === 'DemocyberDown' && alert.job === 'democyber'
        && alert.instance === 'app:8080' && alert.status === 'firing'));
    });
    break;
  }
  default:
    throw new Error('Expected metrics or alert');
}
