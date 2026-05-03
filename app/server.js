const express = require('express');

const app = express();

app.use(express.urlencoded({ extended: true }));
app.use(express.json());

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>DevOps Demo App</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 60px auto; padding: 20px; background: #f5f5f5; }
        h1 { color: #2c3e50; }
        form { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        input[type=text] { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 4px; font-size: 16px; box-sizing: border-box; }
        button { background: #3498db; color: white; padding: 10px 20px; border: none; border-radius: 4px; font-size: 16px; cursor: pointer; }
        button:hover { background: #2980b9; }
        .version { color: #7f8c8d; font-size: 13px; margin-top: 20px; }
      </style>
    </head>
    <body>
      <h1>DevOps Demo App</h1>
      <form action="/greet" method="POST">
        <label for="name"><strong>Enter your name:</strong></label>
        <input type="text" id="name" name="name" placeholder="e.g. Alice" required>
        <button type="submit">Greet Me!</button>
      </form>
      <p class="version">Version: ${process.env.APP_VERSION || '1.0.0'} | Slot: ${process.env.SLOT || 'blue'}</p>
    </body>
    </html>
  `);
});

app.get('/greet/:name', (req, res) => {
  const { name } = req.params;
  const version = process.env.APP_VERSION || '1.0.0';
  const slot = process.env.SLOT || 'blue';
  res.json({ message: `Hello, ${name}!`, version, slot });
});

app.post('/greet', (req, res) => {
  const { name } = req.body;
  if (!name || name.trim() === '') {
    return res.status(400).json({ error: 'Name is required' });
  }
  res.redirect(`/greet/${encodeURIComponent(name.trim())}`);
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    version: process.env.APP_VERSION || '1.0.0',
    slot: process.env.SLOT || 'blue',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (slot: ${process.env.SLOT || 'blue'}, version: ${process.env.APP_VERSION || '1.0.0'})`);
});

module.exports = { app, server };
