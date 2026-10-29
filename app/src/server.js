// server.js — Express app for the Blue-Green-Deployment project.
//
// Serves a Bob Ross painting gallery (data in paintings.js, rendering in
// views.js) plus the ops endpoints the pipeline relies on:
//
//   GET /          gallery (HTML)
//   GET /health    JSON health probe for Nginx + deploy script
//   GET /metrics   Prometheus exposition
//
// APP_COLOR ("blue" | "green") drives the per-instance badge in the UI AND
// is attached as a Prometheus label on every metric, so Grafana can split
// traffic by instance in Phase 7.

const express = require('express');
const client = require('prom-client');
const paintings = require('./paintings');
const views = require('./views');

const PORT = Number(process.env.APP_PORT) || 3000;
const COLOR = process.env.APP_COLOR || 'blue';

const app = express();

// --- Prometheus setup ---
const register = new client.Registry();
register.setDefaultLabels({ app: 'bobross-gallery', color: COLOR });
client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests handled by the app',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});

// Count every request *after* the response is sent so status is accurate.
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status: res.statusCode,
    });
  });
  next();
});

// --- Routes ---

app.get('/', (_req, res) => {
  res.type('html').send(views.index(paintings.all(), COLOR));
});

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    color: COLOR,
    uptime_seconds: Math.round(process.uptime()),
  });
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.send(await register.metrics());
});

// --- Startup ---
const server = app.listen(PORT, () => {
  console.log(`[${COLOR}] listening on :${PORT}`);
});

// Graceful shutdown — matters in Phase 6 when deploys swap containers.
// Without this, Docker SIGKILLs after 10s and in-flight requests drop.
process.on('SIGTERM', () => {
  console.log(`[${COLOR}] SIGTERM received, closing`);
  server.close(() => process.exit(0));
});
