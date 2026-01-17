import { Hono } from 'hono';
import { db } from '../db';
import { users, households, invites, refreshTokens } from '../db/schema';
import { eq, and, gt } from 'drizzle-orm';
import {
  hashPassword,
  verifyPassword,
  generateAccessToken,
  generateRefreshToken,
  getRefreshTokenExpiry,
  generateInviteToken,
  getInviteExpiry,
} from '../services/auth.service';
import { authMiddleware } from '../middleware/auth';
import type { AuthUser } from '../types';

const auth = new Hono<{ Variables: { user: AuthUser } }>();

// Sign up
auth.post('/signup', async (c) => {
  const { email, password, name } = await c.req.json();

  if (!email || !password || !name) {
    return c.json({ error: 'Email, password, and name are required' }, 400);
  }

  const existingUser = await db.query.users.findFirst({
    where: eq(users.email, email),
  });

  if (existingUser) {
    return c.json({ error: 'Email already in use' }, 400);
  }

  const passwordHash = await hashPassword(password);

  const [user] = await db.insert(users).values({
    email,
    name,
    passwordHash,
  }).returning();

  const accessToken = await generateAccessToken({
    userId: user.id,
    householdId: null,
  });

  const refreshToken = await generateRefreshToken();
  await db.insert(refreshTokens).values({
    userId: user.id,
    token: refreshToken,
    expiresAt: getRefreshTokenExpiry(),
  });

  return c.json({
    user: { id: user.id, email: user.email, name: user.name, householdId: null },
    accessToken,
    refreshToken,
  });
});

// Log in
auth.post('/login', async (c) => {
  const { email, password } = await c.req.json();

  if (!email || !password) {
    return c.json({ error: 'Email and password are required' }, 400);
  }

  const user = await db.query.users.findFirst({
    where: eq(users.email, email),
  });

  if (!user || !(await verifyPassword(password, user.passwordHash))) {
    return c.json({ error: 'Invalid email or password' }, 401);
  }

  const accessToken = await generateAccessToken({
    userId: user.id,
    householdId: user.householdId,
  });

  const refreshToken = await generateRefreshToken();
  await db.insert(refreshTokens).values({
    userId: user.id,
    token: refreshToken,
    expiresAt: getRefreshTokenExpiry(),
  });

  return c.json({
    user: { id: user.id, email: user.email, name: user.name, householdId: user.householdId },
    accessToken,
    refreshToken,
  });
});

// Refresh token
auth.post('/refresh', async (c) => {
  const { refreshToken } = await c.req.json();

  if (!refreshToken) {
    return c.json({ error: 'Refresh token is required' }, 400);
  }

  const storedToken = await db.query.refreshTokens.findFirst({
    where: and(
      eq(refreshTokens.token, refreshToken),
      gt(refreshTokens.expiresAt, new Date())
    ),
  });

  if (!storedToken) {
    return c.json({ error: 'Invalid or expired refresh token' }, 401);
  }

  const user = await db.query.users.findFirst({
    where: eq(users.id, storedToken.userId),
  });

  if (!user) {
    return c.json({ error: 'User not found' }, 401);
  }

  // Delete old refresh token
  await db.delete(refreshTokens).where(eq(refreshTokens.id, storedToken.id));

  // Generate new tokens
  const accessToken = await generateAccessToken({
    userId: user.id,
    householdId: user.householdId,
  });

  const newRefreshToken = await generateRefreshToken();
  await db.insert(refreshTokens).values({
    userId: user.id,
    token: newRefreshToken,
    expiresAt: getRefreshTokenExpiry(),
  });

  return c.json({
    accessToken,
    refreshToken: newRefreshToken,
  });
});

// Create household
auth.post('/household', authMiddleware, async (c) => {
  const user = c.get('user');
  const { name } = await c.req.json();

  if (user.householdId) {
    return c.json({ error: 'User already belongs to a household' }, 400);
  }

  if (!name) {
    return c.json({ error: 'Household name is required' }, 400);
  }

  const [household] = await db.insert(households).values({ name }).returning();

  await db.update(users)
    .set({ householdId: household.id })
    .where(eq(users.id, user.id));

  const accessToken = await generateAccessToken({
    userId: user.id,
    householdId: household.id,
  });

  return c.json({ household, accessToken });
});

// Send invite
auth.post('/invite', authMiddleware, async (c) => {
  const user = c.get('user');
  const { email } = await c.req.json();

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household to send invites' }, 400);
  }

  if (!email) {
    return c.json({ error: 'Email is required' }, 400);
  }

  const token = generateInviteToken();

  const [invite] = await db.insert(invites).values({
    householdId: user.householdId,
    email,
    token,
    expiresAt: getInviteExpiry(),
  }).returning();

  // TODO: Send email with invite link
  // For now, return the token directly (dev mode)
  return c.json({
    invite: { id: invite.id, email: invite.email },
    inviteLink: `soughtbox://invite?token=${token}`,
  });
});

// Accept invite
auth.post('/invite/accept', authMiddleware, async (c) => {
  const user = c.get('user');
  const { token } = await c.req.json();

  if (user.householdId) {
    return c.json({ error: 'User already belongs to a household' }, 400);
  }

  if (!token) {
    return c.json({ error: 'Invite token is required' }, 400);
  }

  const invite = await db.query.invites.findFirst({
    where: and(
      eq(invites.token, token),
      gt(invites.expiresAt, new Date())
    ),
  });

  if (!invite || invite.acceptedAt) {
    return c.json({ error: 'Invalid or expired invite' }, 400);
  }

  // Mark invite as accepted
  await db.update(invites)
    .set({ acceptedAt: new Date() })
    .where(eq(invites.id, invite.id));

  // Add user to household
  await db.update(users)
    .set({ householdId: invite.householdId })
    .where(eq(users.id, user.id));

  const household = await db.query.households.findFirst({
    where: eq(households.id, invite.householdId),
  });

  const accessToken = await generateAccessToken({
    userId: user.id,
    householdId: invite.householdId,
  });

  return c.json({ household, accessToken });
});

// Get current user
auth.get('/me', authMiddleware, async (c) => {
  const user = c.get('user');

  let household = null;
  if (user.householdId) {
    household = await db.query.households.findFirst({
      where: eq(households.id, user.householdId),
    });
  }

  return c.json({ user, household });
});

export default auth;
