# Stack Reference: Next.js + Supabase

Load this reference when working on projects using Next.js App Router with Supabase.

## Server Components vs Client Components

| Use Server Components When | Use Client Components When |
|---------------------------|---------------------------|
| Fetching data | Event handlers (onClick, onChange) |
| Accessing backend resources | useState, useEffect, useRef |
| Keeping secrets server-side | Browser APIs (localStorage, geolocation) |
| Reducing client JS bundle | Third-party client-only libraries |

Default to Server Components. Add `'use client'` only when interactivity is required.

## Server Actions vs Route Handlers

| Use Server Actions For | Use Route Handlers For |
|-----------------------|-----------------------|
| Form submissions | Webhooks from external services |
| Simple mutations | Complex multi-step operations |
| Revalidation after writes | Streaming responses |
| When the caller is your own UI | When the caller is external |

## Server Action Pattern

```typescript
'use server';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1).max(255),
  description: z.string().optional(),
});

export async function createItem(formData: FormData) {
  const parsed = schema.safeParse({
    name: formData.get('name'),
    description: formData.get('description'),
  });

  if (!parsed.success) {
    return { error: 'Invalid input' };
  }

  const supabase = await createClient();
  const { error } = await supabase.from('items').insert(parsed.data);

  if (error) {
    return { error: 'Failed to create item' };
  }

  revalidatePath('/items');
  return { success: true };
}
```

## Supabase RLS Patterns

Basic owner check:
```sql
CREATE POLICY "Users can view own data"
ON items FOR SELECT
USING (auth.uid() = user_id);
```

Shared access via team membership:
```sql
CREATE POLICY "Team members can view"
ON items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = items.team_id
    AND team_members.user_id = auth.uid()
  )
);
```

## Data Model Conventions

- `id` — uuid, primary key, default `gen_random_uuid()`
- `created_at` — timestamptz, default `now()`
- `updated_at` — timestamptz, default `now()`
- `user_id` — uuid, FK to `auth.users(id)`, on every table (multi-user readiness)

## Default Folder Structure

```
/src
  /app                # Next.js App Router
    /api              # Route handlers
    /(routes)         # Page routes grouped by feature
    /actions          # Server actions
  /components         # React components
    /ui               # Reusable UI primitives (shadcn/ui)
    /features         # Feature-specific components
    /layout           # Layout components
  /lib                # Utilities
    /db               # Database client, typed queries
    /auth             # Auth utilities
    /utils            # General utilities
    /validators       # Zod schemas
  /types              # TypeScript type definitions
/public               # Static assets
/tests                # Test files (mirrors /src)
/supabase             # Supabase config, migrations, seed
```

## State Management

- Server state (database) is the source of truth
- React Server Components fetch server state directly
- Client state only for genuinely client-side concerns (form state, UI toggles, optimistic updates)
- Do not reach for a state management library unless React state + server state is genuinely insufficient

## Common Data Fetching Pattern

```typescript
// Server Component — fetches directly
export default async function ItemsPage() {
  const supabase = await createClient();
  const { data: items } = await supabase
    .from('items')
    .select('*')
    .order('created_at', { ascending: false });

  return <ItemList items={items ?? []} />;
}
```
