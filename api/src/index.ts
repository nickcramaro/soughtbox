import 'dotenv/config';
import { createServer } from 'node:http';
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { serve } from '@hono/node-server';
import { realtimeService } from './services/realtime.service';
import authRoutes from './routes/auth';
import listsRoutes from './routes/lists';
import choresRoutes from './routes/chores';

const app = new Hono();

// Middleware
app.use('*', cors());
app.use('*', logger());

// Health check
app.get('/', (c) => {
  return c.json({ status: 'ok', name: 'SoughtBox API' });
});

// Routes
app.route('/auth', authRoutes);
app.route('/lists', listsRoutes);
app.route('/chores', choresRoutes);

// 404 handler
app.notFound((c) => {
  return c.json({ error: 'Not found' }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error('Unhandled error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

// Start server with WebSocket support
const port = parseInt(process.env.PORT || '3000', 10);

const server = serve({
  fetch: app.fetch,
  port,
  createServer,
}, (info) => {
  console.log(`SoughtBox API running on http://localhost:${info.port}`);
  console.log(`WebSocket available at ws://localhost:${info.port}/ws`);
});

// Initialize WebSocket server on the HTTP server
realtimeService.initialize(server);
