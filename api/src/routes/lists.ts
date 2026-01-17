import { Hono } from 'hono';
import { db } from '../db';
import { lists, listItems } from '../db/schema';
import { eq, and, asc } from 'drizzle-orm';
import { authMiddleware } from '../middleware/auth';
import { realtimeService } from '../services/realtime.service';
import type { AuthUser } from '../types';

const listsRouter = new Hono<{ Variables: { user: AuthUser } }>();

listsRouter.use('*', authMiddleware);

// Get all lists
listsRouter.get('/', async (c) => {
  const user = c.get('user');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const allLists = await db.query.lists.findMany({
    where: eq(lists.householdId, user.householdId),
    orderBy: [asc(lists.sortOrder)],
    with: {
      items: {
        orderBy: [asc(listItems.sortOrder)],
      },
    },
  });

  return c.json({ lists: allLists });
});

// Create a list
listsRouter.post('/', async (c) => {
  const user = c.get('user');
  const { name, icon } = await c.req.json();

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  if (!name) {
    return c.json({ error: 'List name is required' }, 400);
  }

  const [list] = await db.insert(lists).values({
    householdId: user.householdId,
    name,
    icon,
  }).returning();

  realtimeService.broadcast(user.householdId, {
    type: 'list.created',
    payload: { list },
  });

  return c.json({ list }, 201);
});

// Get a single list
listsRouter.get('/:listId', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const list = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
    with: {
      items: {
        orderBy: [asc(listItems.sortOrder)],
        with: {
          createdBy: true,
        },
      },
    },
  });

  if (!list) {
    return c.json({ error: 'List not found' }, 404);
  }

  return c.json({ list });
});

// Update a list
listsRouter.put('/:listId', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');
  const { name, icon, sortOrder } = await c.req.json();

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const existing = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
  });

  if (!existing) {
    return c.json({ error: 'List not found' }, 404);
  }

  const [list] = await db.update(lists)
    .set({
      ...(name !== undefined && { name }),
      ...(icon !== undefined && { icon }),
      ...(sortOrder !== undefined && { sortOrder }),
    })
    .where(eq(lists.id, listId))
    .returning();

  realtimeService.broadcast(user.householdId, {
    type: 'list.updated',
    payload: { list },
  });

  return c.json({ list });
});

// Delete a list
listsRouter.delete('/:listId', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const existing = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
  });

  if (!existing) {
    return c.json({ error: 'List not found' }, 404);
  }

  await db.delete(lists).where(eq(lists.id, listId));

  realtimeService.broadcast(user.householdId, {
    type: 'list.deleted',
    payload: { listId },
  });

  return c.json({ success: true });
});

// Add item to list
listsRouter.post('/:listId/items', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');
  const { text } = await c.req.json();

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  if (!text) {
    return c.json({ error: 'Item text is required' }, 400);
  }

  const list = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
  });

  if (!list) {
    return c.json({ error: 'List not found' }, 404);
  }

  const [item] = await db.insert(listItems).values({
    listId,
    text,
    createdById: user.id,
  }).returning();

  realtimeService.broadcast(user.householdId, {
    type: 'list_item.created',
    payload: { listId, item },
  });

  return c.json({ item }, 201);
});

// Update item
listsRouter.put('/:listId/items/:itemId', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');
  const itemId = c.req.param('itemId');
  const { text, isCompleted, sortOrder } = await c.req.json();

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const list = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
  });

  if (!list) {
    return c.json({ error: 'List not found' }, 404);
  }

  const existing = await db.query.listItems.findFirst({
    where: and(eq(listItems.id, itemId), eq(listItems.listId, listId)),
  });

  if (!existing) {
    return c.json({ error: 'Item not found' }, 404);
  }

  const [item] = await db.update(listItems)
    .set({
      ...(text !== undefined && { text }),
      ...(isCompleted !== undefined && {
        isCompleted,
        completedAt: isCompleted ? new Date() : null,
      }),
      ...(sortOrder !== undefined && { sortOrder }),
    })
    .where(eq(listItems.id, itemId))
    .returning();

  realtimeService.broadcast(user.householdId, {
    type: 'list_item.updated',
    payload: { listId, item },
  });

  return c.json({ item });
});

// Delete item
listsRouter.delete('/:listId/items/:itemId', async (c) => {
  const user = c.get('user');
  const listId = c.req.param('listId');
  const itemId = c.req.param('itemId');

  if (!user.householdId) {
    return c.json({ error: 'User must belong to a household' }, 400);
  }

  const list = await db.query.lists.findFirst({
    where: and(eq(lists.id, listId), eq(lists.householdId, user.householdId)),
  });

  if (!list) {
    return c.json({ error: 'List not found' }, 404);
  }

  const existing = await db.query.listItems.findFirst({
    where: and(eq(listItems.id, itemId), eq(listItems.listId, listId)),
  });

  if (!existing) {
    return c.json({ error: 'Item not found' }, 404);
  }

  await db.delete(listItems).where(eq(listItems.id, itemId));

  realtimeService.broadcast(user.householdId, {
    type: 'list_item.deleted',
    payload: { listId, itemId },
  });

  return c.json({ success: true });
});

export default listsRouter;
