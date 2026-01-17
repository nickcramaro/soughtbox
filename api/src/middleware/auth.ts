import { Context, Next } from 'hono';
import { jwtVerify } from 'jose';
import { db } from '../db';
import { users } from '../db/schema';
import { eq } from 'drizzle-orm';
import type { AuthUser, JWTPayload } from '../types';

const JWT_SECRET = new TextEncoder().encode(process.env.JWT_SECRET || 'dev-secret-change-in-production');

export async function authMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization');

  if (!authHeader?.startsWith('Bearer ')) {
    return c.json({ error: 'Missing or invalid authorization header' }, 401);
  }

  const token = authHeader.slice(7);

  try {
    const { payload } = await jwtVerify(token, JWT_SECRET) as { payload: JWTPayload };

    const user = await db.query.users.findFirst({
      where: eq(users.id, payload.userId),
    });

    if (!user) {
      return c.json({ error: 'User not found' }, 401);
    }

    const authUser: AuthUser = {
      id: user.id,
      email: user.email,
      name: user.name,
      householdId: user.householdId,
    };

    c.set('user', authUser);
    await next();
  } catch {
    return c.json({ error: 'Invalid token' }, 401);
  }
}
