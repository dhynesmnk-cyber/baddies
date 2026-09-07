-- Becoming Baddies - enable Realtime
--
-- Run this once in the Supabase SQL Editor. It is safe to run repeatedly.
-- New projects get this automatically: the same block is at the end of
-- sql/schema.sql. This standalone file is for projects created before live
-- sync was added.
--
-- Two things are needed for live sync:
--
--   1. replica identity full, so UPDATE and DELETE events carry the whole row
--      rather than just the primary key. Without it a deleted log arrives with
--      no profile_id and the app cannot tell whose it was.
--   2. membership of the supabase_realtime publication, which is what actually
--      streams the changes.
--
-- Row level security still applies to the stream. The select policies in
-- schema.sql let both signed in users read everything, so both see each
-- other's changes. Writes stay owner only.

alter table public.profiles replica identity full;
alter table public.activities replica identity full;
alter table public.routine_items replica identity full;
alter table public.logs replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end
$$;

do $$
declare
  target text;
begin
  foreach target in array array['profiles', 'activities', 'routine_items', 'logs']
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target
    ) then
      execute format('alter publication supabase_realtime add table public.%I', target);
    end if;
  end loop;
end
$$;
