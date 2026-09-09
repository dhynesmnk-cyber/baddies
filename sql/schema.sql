-- Becoming Baddies - Supabase schema
-- Run this once in the Supabase SQL Editor for your project.
--
-- Model notes:
--   profiles       one per auth user. Everyone can read all profiles (that is the point
--                  of a two person competition). You can only write your own.
--   activities     shared library. Any signed in user can edit it.
--   routine_items  per profile plan. Rows are snapshots of a library activity so Dave and
--                  Angus can use the same exercise with different targets. Most rows repeat
--                  weekly by day; a row with one_off_date set instead belongs to that single
--                  date, for whatever does not fit a fixed weekly plan.
--   logs           one row per profile / date / routine item. Upserted as you tick sets,
--                  save a distance or stop a timer.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  type text not null check (type in ('strength', 'distance', 'timer')),
  sets int not null default 0,
  reps text not null default '',
  rest_seconds int not null default 0,
  target_km numeric not null default 0,
  target_seconds int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.routine_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  day text not null check (day in (
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  )),
  position int not null default 0,
  activity_id uuid references public.activities(id) on delete set null,
  name text not null,
  type text not null check (type in ('strength', 'distance', 'timer')),
  sets int not null default 0,
  reps text not null default '',
  rest_seconds int not null default 0,
  target_km numeric not null default 0,
  target_seconds int not null default 0
);

-- Added after the initial release. On an existing project this is what actually
-- brings the one-off feature in; re-running the file above this line is a no-op.
alter table public.routine_items add column if not exists one_off_date date;

create table if not exists public.logs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  log_date date not null,
  routine_item_id uuid references public.routine_items(id) on delete set null,
  activity_id uuid references public.activities(id) on delete set null,
  name text not null,
  type text not null check (type in ('strength', 'distance', 'timer')),
  strength_sets jsonb not null default '[]',
  distance_km numeric,
  duration_seconds int,
  updated_at timestamptz not null default now(),
  constraint logs_unique_entry unique (profile_id, log_date, routine_item_id)
);

create index if not exists routine_profile_day_idx
  on public.routine_items(profile_id, day, position);

create index if not exists routine_profile_one_off_idx
  on public.routine_items(profile_id, one_off_date)
  where one_off_date is not null;

create index if not exists logs_profile_date_idx
  on public.logs(profile_id, log_date);

create index if not exists logs_activity_idx
  on public.logs(activity_id);

alter table public.profiles enable row level security;
alter table public.activities enable row level security;
alter table public.routine_items enable row level security;
alter table public.logs enable row level security;

create or replace function public.is_profile_owner(p uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = p
      and owner_id = auth.uid()
  );
$$;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select
on public.profiles
for select
to authenticated
using (true);

drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert
on public.profiles
for insert
to authenticated
with check (owner_id = auth.uid());

drop policy if exists profiles_update on public.profiles;
create policy profiles_update
on public.profiles
for update
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete
on public.profiles
for delete
to authenticated
using (owner_id = auth.uid());

drop policy if exists activities_select on public.activities;
create policy activities_select
on public.activities
for select
to authenticated
using (true);

drop policy if exists activities_insert on public.activities;
create policy activities_insert
on public.activities
for insert
to authenticated
with check (true);

drop policy if exists activities_update on public.activities;
create policy activities_update
on public.activities
for update
to authenticated
using (true)
with check (true);

drop policy if exists activities_delete on public.activities;
create policy activities_delete
on public.activities
for delete
to authenticated
using (true);

drop policy if exists routine_select on public.routine_items;
create policy routine_select
on public.routine_items
for select
to authenticated
using (true);

drop policy if exists routine_insert on public.routine_items;
create policy routine_insert
on public.routine_items
for insert
to authenticated
with check (public.is_profile_owner(profile_id));

drop policy if exists routine_update on public.routine_items;
create policy routine_update
on public.routine_items
for update
to authenticated
using (public.is_profile_owner(profile_id))
with check (public.is_profile_owner(profile_id));

drop policy if exists routine_delete on public.routine_items;
create policy routine_delete
on public.routine_items
for delete
to authenticated
using (public.is_profile_owner(profile_id));

drop policy if exists logs_select on public.logs;
create policy logs_select
on public.logs
for select
to authenticated
using (true);

drop policy if exists logs_insert on public.logs;
create policy logs_insert
on public.logs
for insert
to authenticated
with check (public.is_profile_owner(profile_id));

drop policy if exists logs_update on public.logs;
create policy logs_update
on public.logs
for update
to authenticated
using (public.is_profile_owner(profile_id))
with check (public.is_profile_owner(profile_id));

drop policy if exists logs_delete on public.logs;
create policy logs_delete
on public.logs
for delete
to authenticated
using (public.is_profile_owner(profile_id));

insert into public.activities (name, type, sets, reps, rest_seconds, target_km, target_seconds)
values
  ('Push Up', 'strength', 3, '10', 60, 0, 0),
  ('Bodyweight Row', 'strength', 3, '10', 60, 0, 0),
  ('Pull Up', 'strength', 3, '6', 90, 0, 0),
  ('Bodyweight Squat', 'strength', 3, '15', 60, 0, 0),
  ('Walking Lunge', 'strength', 3, '12', 60, 0, 0),
  ('Standing Calf Raise', 'strength', 3, '15', 60, 0, 0),
  ('Seated Calf Raise', 'strength', 3, '20', 60, 0, 0),
  ('Tibialis Raise', 'strength', 3, '20', 45, 0, 0),
  ('Run', 'distance', 0, '', 0, 3, 0),
  ('Swim', 'distance', 0, '', 0, 1, 0),
  ('Skipping', 'timer', 0, '', 0, 0, 300),
  ('Boxing', 'timer', 0, '', 0, 0, 300),
  ('Plank', 'timer', 0, '', 0, 0, 60)
on conflict (name) do nothing;
