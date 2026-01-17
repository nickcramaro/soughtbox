import { WebSocket, WebSocketServer } from 'ws';
import { verifyAccessToken } from './auth.service';
import type { IncomingMessage } from 'http';

interface AuthenticatedSocket extends WebSocket {
  userId?: string;
  householdId?: string | null;
  isAlive?: boolean;
}

interface BroadcastMessage {
  type: string;
  payload: unknown;
}

class RealtimeService {
  private wss: WebSocketServer | null = null;
  private connections: Map<string, Set<AuthenticatedSocket>> = new Map();

  initialize(server: ReturnType<typeof import('http').createServer>) {
    this.wss = new WebSocketServer({ server, path: '/ws' });

    this.wss.on('connection', (ws: AuthenticatedSocket, req: IncomingMessage) => {
      ws.isAlive = true;

      ws.on('pong', () => {
        ws.isAlive = true;
      });

      ws.on('message', async (data) => {
        try {
          const message = JSON.parse(data.toString());

          if (message.type === 'auth') {
            const payload = await verifyAccessToken(message.token);
            if (payload) {
              ws.userId = payload.userId;
              ws.householdId = payload.householdId;

              if (payload.householdId) {
                if (!this.connections.has(payload.householdId)) {
                  this.connections.set(payload.householdId, new Set());
                }
                this.connections.get(payload.householdId)!.add(ws);
              }

              ws.send(JSON.stringify({ type: 'auth.success' }));
            } else {
              ws.send(JSON.stringify({ type: 'auth.error', message: 'Invalid token' }));
              ws.close();
            }
          }
        } catch {
          ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
        }
      });

      ws.on('close', () => {
        if (ws.householdId) {
          const householdConnections = this.connections.get(ws.householdId);
          if (householdConnections) {
            householdConnections.delete(ws);
            if (householdConnections.size === 0) {
              this.connections.delete(ws.householdId);
            }
          }
        }
      });
    });

    // Heartbeat to detect dead connections
    const interval = setInterval(() => {
      this.wss?.clients.forEach((ws) => {
        const socket = ws as AuthenticatedSocket;
        if (socket.isAlive === false) {
          return socket.terminate();
        }
        socket.isAlive = false;
        socket.ping();
      });
    }, 30000);

    this.wss.on('close', () => {
      clearInterval(interval);
    });
  }

  broadcast(householdId: string, message: BroadcastMessage) {
    const connections = this.connections.get(householdId);
    if (!connections) return;

    const data = JSON.stringify(message);
    connections.forEach((ws) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(data);
      }
    });
  }
}

export const realtimeService = new RealtimeService();
