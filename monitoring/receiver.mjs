import { createServer } from 'node:http';

const alerts = new Map();

createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/alerts') {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify([...alerts.values()]));
    return;
  }
  if (request.method !== 'POST' || request.url !== '/alerts') {
    response.writeHead(404).end();
    return;
  }

  try {
    let body = '';
    for await (const chunk of request) {
      body += chunk;
      if (body.length > 64 * 1024) {
        response.writeHead(413).end();
        return;
      }
    }
    const notification = JSON.parse(body);
    if (!Array.isArray(notification.alerts)) {
      response.writeHead(400).end();
      return;
    }
    for (const alert of notification.alerts) {
      if (alert.labels?.alertname === 'DemocyberDown' && alert.labels?.job === 'democyber' &&
          ['firing', 'resolved'].includes(alert.status)) {
        alerts.set(alert.status, {
          name: alert.labels.alertname, job: alert.labels.job,
          instance: alert.labels.instance, status: alert.status, startsAt: alert.startsAt,
        });
      }
    }
    response.writeHead(204).end();
  } catch {
    response.writeHead(400).end();
  }
}).listen(8080, '0.0.0.0');
