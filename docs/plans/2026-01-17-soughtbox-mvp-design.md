# SoughtBox MVP Design

A couples organizing app with modular features, starting with shared lists and a chore pool.

## Overview

**What:** iOS app for you and your partner to coordinate daily life - shared lists, chore tracking, with room to add more modules later.

**Tech Stack:**
- **iOS:** SwiftUI (iOS 17+), Swift 5.9+
- **Backend:** Node.js + TypeScript, Hono framework
- **Database:** PostgreSQL on Railway
- **Real-time:** WebSocket for instant sync
- **Auth:** Email + password with JWT

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   iOS App       │◄──────► │   API Server    │
│   (SwiftUI)     │   WS    │   (Node/TS)     │
└─────────────────┘         └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │    PostgreSQL   │
                            │    (Railway)    │
                            └─────────────────┘
```

## Data Model

```sql
-- Core
User
├── id
├── email
├── name
├── passwordHash
└── householdId (FK)

Household
├── id
├── name
└── createdAt

Invite
├── id
├── householdId (FK)
├── email
├── token
├── expiresAt
└── acceptedAt

-- Lists Module
List
├── id
├── householdId (FK)
├── name
├── icon
└── sortOrder

ListItem
├── id
├── listId (FK)
├── text
├── isCompleted
├── createdById (FK)
├── sortOrder
└── completedAt

-- Chores Module
Chore
├── id
├── householdId (FK)
├── name
├── frequency (daily/weekly/monthly/as-needed)
└── effortLevel (light/medium/heavy)

ChoreCompletion
├── id
├── choreId (FK)
├── completedById (FK)
└── completedAt
```

## iOS App Structure

```
SoughtBox/
├── App/
│   └── SoughtBoxApp.swift
├── Models/
│   ├── User.swift
│   ├── Household.swift
│   ├── List.swift
│   └── Chore.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ListsViewModel.swift
│   └── ChoresViewModel.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── Lists/
│   │   ├── ListsHomeView.swift
│   │   └── ListDetailView.swift
│   ├── Chores/
│   │   └── ChorePoolView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Services/
│   ├── APIClient.swift
│   ├── WebSocketClient.swift
│   └── AuthService.swift
└── Components/
    └── (Reusable UI)
```

## Backend Structure

```
soughtbox-api/
├── src/
│   ├── index.ts
│   ├── routes/
│   │   ├── auth.ts
│   │   ├── lists.ts
│   │   └── chores.ts
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── email.service.ts
│   │   └── realtime.service.ts
│   ├── db/
│   │   ├── schema.ts
│   │   ├── migrations/
│   │   └── index.ts
│   ├── middleware/
│   │   └── auth.ts
│   └── types/
│       └── index.ts
├── drizzle.config.ts
├── package.json
└── tsconfig.json
```

**Dependencies:**
- Hono (HTTP framework)
- Drizzle ORM (database)
- jose (JWT)
- ws (WebSocket)
- Resend (emails)

## Real-Time Sync

1. iOS app opens WebSocket to `wss://api.soughtbox.app/ws`
2. First message sends JWT for authentication
3. Server associates connection with user's household
4. All mutations go through REST (POST/PUT/DELETE)
5. Server broadcasts changes via WebSocket to all household members

**Message format:**
```json
{
  "type": "list_item.created",
  "payload": { "listId": "123", "item": { "id": "456", "text": "Milk" } }
}
```

**Reconnection:** Auto-reconnect with exponential backoff, fetch latest state on reconnect.

## Authentication Flow

**Signup:**
1. User enters email, password, name
2. Server creates User (no household yet), returns JWT
3. User creates new Household or accepts an invite

**Invite flow:**
1. Partner A creates invite via POST /invite with partner's email
2. Server sends email with link: `soughtbox://invite?token=abc`
3. Partner B opens link, app calls POST /invite/accept
4. Server adds Partner B to household, returns JWT

**Tokens:**
- Access token: 15 min expiry
- Refresh token: 30 days
- Stored in iOS Keychain

## App Navigation

```
┌─────────────────────────────────────┐
│           [Screen Content]          │
├─────────┬─────────┬─────────────────┤
│  Lists  │  Chores │     Settings    │
└─────────┴─────────┴─────────────────┘
```

**Lists Tab:**
- ListsHomeView: All lists with item counts
- ListDetailView: Items in a list, add/check off/reorder

**Chores Tab:**
- ChorePoolView: All chores, who last did them, claim completions

**Settings Tab:**
- Account info, household management, sign out

## Error Handling & Offline

- Optimistic updates: UI updates immediately, rolls back on error
- Offline: Cache data for reading, queue writes for when online
- Conflict resolution: Last write wins (simple for MVP)
- Show inline errors, not blocking alerts

## Module System

No complex plugin architecture. Just organized folders:
- Each module = database tables + route file + Views folder
- All linked via `householdId`
- To add a module: add tables, add routes, add views

## Build Order

1. API: Auth endpoints (signup, login, refresh)
2. iOS: Login/signup screens, token storage
3. API: Household + invite endpoints
4. iOS: Household creation/join flow
5. API: Lists CRUD + WebSocket
6. iOS: Lists feature with real-time
7. API: Chores CRUD
8. iOS: Chores feature
9. Polish, deploy, use it

## Development Setup

**Prerequisites:**
- Xcode 15+
- Node.js 20+
- pnpm
- Railway CLI

**Project structure:**
```
soughtbox/
├── ios/
├── api/
└── docs/plans/
```

**Workflow:**
1. Postgres via Docker locally (or Railway dev DB)
2. API: `pnpm dev` with hot reload
3. iOS: Xcode Simulator → localhost:3000
4. Deploy API to Railway for device testing
