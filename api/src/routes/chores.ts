import { Hono } from 'hono';
import { db } from '../db';
import { chores, choreCompletions, users } from '../db/schema';
import { eq, and, desc } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth';
import { realtimeService } from '../services/realtime.service';
import type { AuthUser, Frequency, EffortLevel } from '../types';

const choresRouter = new Hono<{ Variables: { user: AuthUser } }>();

choresRouter.use('*', authMiddleware);

// Get all chores with latest completion
choresRouter.get('/', async (c) => {
  const user = c.get('user');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const allChores = await db.query.chores.findMany({
    where: eq(chores.householdId, user.householdId),
    with: {
      completions: {
        orderBy: [desc(choreCompletions.completedAt)],
        limit: 1,
        with: {
          completedBy: true,
        },
      },
    },
  });

  // Transform to include lastCompletion at top level
  const choresWithLastCompletion = allChores.map((chore) => ({
    ...chore,
    lastCompletion: chore.completions[0] || null,
    completions: undefined,
  }));

  return c.json({ chores: choresWithLastCompletion });
});

// Create a chore
choresRouter.post('/', async (c) => {
  const user = c.get('user');
  const { name, frequency, effortLevel } = await c.req.json() as {
    name: string;
    frequency?: Frequency;
    effortLevel?: EffortLevel;
  };

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  if (!name) {
    return c.json({ error: 'Chore name is required' }, 400);
  }

  const [chore] = await db.insert(chores).values({
    householdId: user.householdId,
    name,
    frequency: frequency || 'as-needed',
    effortLevel: effortLevel || 'medium',
  }).returning();

  realtimeService.broadcast(user.householdId, {
    type: 'chore.created',
    payload: { chore },
  });

  return c.json({ chore }, 201);
});

// Get a single chore with completion history
choresRouter.get('/:choreId', async (c) => {
  const user = c.get('user');
  const choreId = c.req.param('choreId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const chore = await db.query.chores.findFirst({
    where: and(eq(chores.id, choreId), eq(chores.householdId, user.householdId)),
    with: {
      completions: {
        orderBy: [desc(choreCompletions.completedAt)],
        limit: 10,
        with: {
          completedBy: true,
        },
      },
    },
  });

  if (!chore) {
    return c.json({ error: 'Chore not found' }, 404);
  }

  return c.json({ chore });
});

// Update a chore
choresRouter.put('/:choreId', async (c) => {
  const user = c.get('user');
  const choreId = c.req.param('choreId');
  const { name, frequency, effortLevel } = await c.req.json() as {
    name?: string;
    frequency?: Frequency;
    effortLevel?: EffortLevel;
  };

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const existing = await db.query.chores.findFirst({
    where: and(eq(chores.id, choreId), eq(chores.householdId, user.householdId)),
  });

  if (!existing) {
    return c.json({ error: 'Chore not found' }, 404);
  }

  const [chore] = await db.update(chores)
    .set({
      ...(name !== undefined && { name }),
      ...(frequency !== undefined && { frequency }),
      ...(effortLevel !== undefined && { effortLevel }),
    })
    .where(eq(chores.id, choreId))
    .returning();

  realtimeService.broadcast(user.householdId, {
    type: 'chore.updated',
    payload: { chore },
  });

  return c.json({ chore });
});

// Delete a chore
choresRouter.delete('/:choreId', async (c) => {
  const user = c.get('user');
  const choreId = c.req.param('choreId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const existing = await db.query.chores.findFirst({
    where: and(eq(chores.id, choreId), eq(chores.householdId, user.householdId)),
  });

  if (!existing) {
    return c.json({ error: 'Chore not found' }, 404);
  }

  await db.delete(chores).where(eq(chores.id, choreId));

  realtimeService.broadcast(user.householdId, {
    type: 'chore.deleted',
    payload: { choreId },
  });

  return c.json({ success: true });
});

// Complete a chore ("I did this")
choresRouter.post('/:choreId/complete', async (c) => {
  const user = c.get('user');
  const choreId = c.req.param('choreId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const chore = await db.query.chores.findFirst({
    where: and(eq(chores.id, choreId), eq(chores.householdId, user.householdId)),
  });

  if (!chore) {
    return c.json({ error: 'Chore not found' }, 404);
  }

  const [completion] = await db.insert(choreCompletions).values({
    choreId,
    completedById: user.id,
  }).returning();

  const completedBy = await db.query.users.findFirst({
    where: eq(users.id, user.id),
  });

  const completionWithUser = {
    ...completion,
    completedBy: completedBy ? { id: completedBy.id, name: completedBy.name } : null,
  };

  realtimeService.broadcast(user.householdId, {
    type: 'chore.completed',
    payload: { choreId, completion: completionWithUser },
  });

  return c.json({ completion: completionWithUser }, 201);
});

export default choresRouter;
