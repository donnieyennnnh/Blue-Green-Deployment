// server.test.js — smoke tests for the three endpoints.
// Uses supertest to drive the Express app in-process (no real network).

const request = require('supertest');
const app = require('../src/server');

describe('GET /health', () => {
  test('returns ok status with the configured color', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(['blue', 'green']).toContain(res.body.color);
    expect(typeof res.body.uptime_seconds).toBe('number');
  });
});

describe('GET /', () => {
  test('serves the HTML gallery with the project title', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
    expect(res.text).toContain('The Joy of Deploying');
    expect(res.text).toContain('Mountain Hide-Away'); // from paintings.js
  });
});

describe('GET /metrics', () => {
  test('serves Prometheus exposition format with our custom labels', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/plain/);
    expect(res.text).toContain('process_cpu_user_seconds_total');
    expect(res.text).toMatch(/app="bobross-gallery"/);
  });
});
