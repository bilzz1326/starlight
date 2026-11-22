-- Starlight accounts and cloud save: run this once in Supabase (SQL Editor -> New query -> paste -> Run),
-- after setup.sql. It stores each signed-in player's progress so they can continue on another device.

create table if not exists public.saves (
  id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint save_not_too_big check (pg_column_size(data) < 20000)
);

grant select, insert, update on public.saves to authenticated;

-- Each player can only see and change their own save. Nobody else can read it.
alter table public.saves enable row level security;

drop policy if exists "players read their own save" on public.saves;
create policy "players read their own save" on public.saves
  for select to authenticated using (id = auth.uid());

drop policy if exists "players add their own save" on public.saves;
create policy "players add their own save" on public.saves
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "players update their own save" on public.saves;
create policy "players update their own save" on public.saves
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- When a guest signs in, the game moves their score to the account and removes the old guest row.
-- Players can only remove their own row.
grant delete on public.scores to authenticated;
drop policy if exists "players remove their own row" on public.scores;
create policy "players remove their own row" on public.scores
  for delete to authenticated using (id = auth.uid());
