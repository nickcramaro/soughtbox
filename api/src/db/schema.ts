import { pgTable, uuid, text, timestamp, boolean, integer, pgEnum } from 'drizzle-orm/pg-core';
import { relations } from 'drizzle-orm';

// Enums
export const frequencyEnum = pgEnum('frequency', ['daily', 'weekly', 'monthly', 'as-needed']);
export const effortLevelEnum = pgEnum('effort_level', ['light', 'medium', 'heavy']);

// Core tables
export const households = pgTable('households', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const users = pgTable('users', {
  id: uuid('id').primaryKey().defaultRandom(),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  passwordHash: text('password_hash').notNull(),
  householdId: uuid('household_id').references(() => households.id),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const refreshTokens = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().defaultRandom(),
  userId: uuid('user_id').references(() => users.id).notNull(),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const invites = pgTable('invites', {
  id: uuid('id').primaryKey().defaultRandom(),
  householdId: uuid('household_id').references(() => households.id).notNull(),
  email: text('email').notNull(),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  acceptedAt: timestamp('accepted_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Lists module
export const lists = pgTable('lists', {
  id: uuid('id').primaryKey().defaultRandom(),
  householdId: uuid('household_id').references(() => households.id).notNull(),
  name: text('name').notNull(),
  icon: text('icon'),
  sortOrder: integer('sort_order').default(0).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const listItems = pgTable('list_items', {
  id: uuid('id').primaryKey().defaultRandom(),
  listId: uuid('list_id').references(() => lists.id, { onDelete: 'cascade' }).notNull(),
  text: text('text').notNull(),
  isCompleted: boolean('is_completed').default(false).notNull(),
  createdById: uuid('created_by_id').references(() => users.id).notNull(),
  sortOrder: integer('sort_order').default(0).notNull(),
  completedAt: timestamp('completed_at'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

// Chores module
export const chores = pgTable('chores', {
  id: uuid('id').primaryKey().defaultRandom(),
  householdId: uuid('household_id').references(() => households.id).notNull(),
  name: text('name').notNull(),
  frequency: frequencyEnum('frequency').default('as-needed').notNull(),
  effortLevel: effortLevelEnum('effort_level').default('medium').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
});

export const choreCompletions = pgTable('chore_completions', {
  id: uuid('id').primaryKey().defaultRandom(),
  choreId: uuid('chore_id').references(() => chores.id, { onDelete: 'cascade' }).notNull(),
  completedById: uuid('completed_by_id').references(() => users.id).notNull(),
  completedAt: timestamp('completed_at').defaultNow().notNull(),
});

// Relations
export const householdsRelations = relations(households, ({ many }) => ({
  users: many(users),
  invites: many(invites),
  lists: many(lists),
  chores: many(chores),
}));

export const usersRelations = relations(users, ({ one, many }) => ({
  household: one(households, {
    fields: [users.householdId],
    references: [households.id],
  }),
  refreshTokens: many(refreshTokens),
  listItems: many(listItems),
  choreCompletions: many(choreCompletions),
}));

export const listsRelations = relations(lists, ({ one, many }) => ({
  household: one(households, {
    fields: [lists.householdId],
    references: [households.id],
  }),
  items: many(listItems),
}));

export const listItemsRelations = relations(listItems, ({ one }) => ({
  list: one(lists, {
    fields: [listItems.listId],
    references: [lists.id],
  }),
  createdBy: one(users, {
    fields: [listItems.createdById],
    references: [users.id],
  }),
}));

export const choresRelations = relations(chores, ({ one, many }) => ({
  household: one(households, {
    fields: [chores.householdId],
    references: [households.id],
  }),
  completions: many(choreCompletions),
}));

export const choreCompletionsRelations = relations(choreCompletions, ({ one }) => ({
  chore: one(chores, {
    fields: [choreCompletions.choreId],
    references: [chores.id],
  }),
  completedBy: one(users, {
    fields: [choreCompletions.completedById],
    references: [users.id],
  }),
}));
