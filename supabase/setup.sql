-- Starlight leaderboard: run this once in Supabase (SQL Editor -> New query -> paste -> Run).
-- Players are anonymous: Supabase gives each browser a random id, no email or name is collected.

create table if not exists public.scores (
  id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  nick text not null,
  explorer integer not null default 0 check (explorer between 0 and 5000),
  challenge integer not null default 0 check (challenge between 0 and 5000),
  far integer not null default 0 check (far between 0 and 5000),
  updated_at timestamptz not null default now(),
  -- kid safety: nicknames can only be built from the game's own word lists, e.g. "Happy Otter 37"
  constraint nick_is_safe check (
    split_part(nick, ' ', 1) = any (array['Brave','Happy','Cosmic','Sparkly','Speedy','Sleepy','Lucky','Jolly','Starry','Mighty','Gentle','Zippy'])
    and split_part(nick, ' ', 2) = any (array['Comet','Rocket','Panda','Otter','Fox','Owl','Moon','Nova','Koala','Dolphin','Penguin','Meteor'])
    and split_part(nick, ' ', 3) ~ '^[1-9][0-9]$'
    and split_part(nick, ' ', 4) = ''
  )
);

create index if not exists scores_explorer_idx on public.scores (explorer desc);
create index if not exists scores_challenge_idx on public.scores (challenge desc);

-- Let the game use the table at all (newer Supabase projects don't grant this automatically).
-- What each player may actually do is limited by the row level security rules below.
grant select on public.scores to anon, authenticated;
grant insert, update on public.scores to authenticated;

-- Row level security: everyone can read the board, each player can only write their own row
alter table public.scores enable row level security;

drop policy if exists "anyone can read scores" on public.scores;
create policy "anyone can read scores" on public.scores
  for select to anon, authenticated using (true);

drop policy if exists "players add their own row" on public.scores;
create policy "players add their own row" on public.scores
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "players update their own row" on public.scores;
create policy "players update their own row" on public.scores
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Scores can only go up (a player can't lower their own best by accident)
create or replace function public.scores_keep_best() returns trigger
language plpgsql as $$
begin
  new.explorer   := greatest(new.explorer, old.explorer);
  new.challenge  := greatest(new.challenge, old.challenge);
  new.far        := greatest(new.far, old.far);
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists scores_keep_best on public.scores;
create trigger scores_keep_best before update on public.scores
  for each row execute function public.scores_keep_best();
