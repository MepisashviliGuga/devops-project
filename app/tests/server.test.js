const request = require('supertest');
const { app, server } = require('../server');

afterAll((done) => {
  server.close(done);
});

describe('GET /', () => {
  test('returns 200 and HTML home page', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
    expect(res.text).toContain('DevOps Demo App');
  });

  test('home page contains the greeting form', async () => {
    const res = await request(app).get('/');
    expect(res.text).toContain('<form');
    expect(res.text).toContain('action="/greet"');
  });
});

describe('GET /greet/:name', () => {
  test('greets user by name with JSON response', async () => {
    const res = await request(app).get('/greet/Alice');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello, Alice!');
  });

  test('response includes version and slot fields', async () => {
    const res = await request(app).get('/greet/Bob');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('slot');
  });

  test('handles URL-encoded names correctly', async () => {
    const res = await request(app).get('/greet/John%20Doe');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello, John Doe!');
  });
});

describe('POST /greet', () => {
  test('redirects to /greet/:name when name is provided', async () => {
    const res = await request(app)
      .post('/greet')
      .send('name=Alice')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.statusCode).toBe(302);
    expect(res.headers.location).toContain('/greet/Alice');
  });

  test('returns 400 when name is missing', async () => {
    const res = await request(app)
      .post('/greet')
      .send('')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe('Name is required');
  });

  test('returns 400 when name is only whitespace', async () => {
    const res = await request(app)
      .post('/greet')
      .send('name=   ')
      .set('Content-Type', 'application/x-www-form-urlencoded');
    expect(res.statusCode).toBe(400);
  });
});

describe('GET /health', () => {
  test('returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('health response includes required fields', async () => {
    const res = await request(app).get('/health');
    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('version');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('slot');
  });

  test('timestamp is a valid ISO date string', async () => {
    const res = await request(app).get('/health');
    const date = new Date(res.body.timestamp);
    expect(date.toString()).not.toBe('Invalid Date');
  });
});

describe('404 handler', () => {
  test('returns 404 for unknown routes', async () => {
    const res = await request(app).get('/nonexistent-route');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Not found');
  });
});
