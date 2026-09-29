-- Zine Maker: temporary cloud saves
-- Rules: each visitor keeps at most 3 zines, each deleted 24 hours after it was first saved.
-- Run once in the Supabase SQL editor. Before running, turn on:
--   Authentication → Sign In / Providers → "Allow anonymous sign-ins"
-- Then create a PRIVATE storage bucket named  zine-photos
--   file size limit: 2 MB, allowed MIME types: image/jpeg

-- ---------------------------------------------------------------- table
create table public.zines (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid() references auth.users on delete cascade,
  title       text check (char_length(title) <= 120),
  cover       text check (char_length(cover) < 200000),        -- small JPEG thumbnail (data URL)
  layout      jsonb not null check (pg_column_size(layout) < 200000),
                                            -- date, description, paper, cells, photo dimensions
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '1 day'
);
create index zines_owner_idx   on public.zines (owner);
create index zines_expires_idx on public.zines (expires_at);

alter table public.zines enable row level security;

-- Visitors only ever see and change their own zines, and expired ones disappear
-- immediately even before the hourly cleanup removes them.
create policy "zines: read own live"   on public.zines for select to authenticated
  using (owner = auth.uid() and expires_at > now());
create policy "zines: create own"      on public.zines for insert to authenticated
  with check (owner = auth.uid());
create policy "zines: edit own live"   on public.zines for update to authenticated
  using (owner = auth.uid() and expires_at > now())
  with check (owner = auth.uid());
create policy "zines: delete own"      on public.zines for delete to authenticated
  using (owner = auth.uid());

-- ------------------------------------------------------- limits (server-enforced)
-- Clock starts at first save and is never extended; the browser can't override it.
create or replace function public.zine_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at := now();
  new.expires_at := now() + interval '1 day';

  if (select count(*) from public.zines
      where owner = new.owner and expires_at > now()) >= 3 then
    raise exception 'ZINE_LIMIT';
  end if;

  -- Site-wide ceiling to protect the free tier from abuse; adjust as needed.
  if (select count(*) from public.zines where expires_at > now()) >= 60 then
    raise exception 'SITE_FULL';
  end if;

  return new;
end $$;

create trigger zine_before_insert before insert on public.zines
  for each row execute function public.zine_before_insert();

create or replace function public.zine_before_update() returns trigger
language plpgsql as $$
begin
  new.owner      := old.owner;
  new.created_at := old.created_at;
  new.expires_at := old.expires_at;
  return new;
end $$;

create trigger zine_before_update before update on public.zines
  for each row execute function public.zine_before_update();

-- ------------------------------------------------------------ photo storage
-- Paths are  <user id>/<zine id>/<photo id>.jpg
-- Uploads are only allowed into a zine the visitor owns that hasn't expired,
-- so photos can't pile up without a zine attached.
create policy "zine photos: read own" on storage.objects for select to authenticated
  using (bucket_id = 'zine-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);

create policy "zine photos: upload to own live zine" on storage.objects for insert to authenticated
  with check (bucket_id = 'zine-photos'
              and (storage.foldername(name))[1] = auth.uid()::text
              and exists (select 1 from public.zines z
                          where z.id::text = (storage.foldername(name))[2]
                            and z.owner = auth.uid()
                            and z.expires_at > now()));

create policy "zine photos: replace in own live zine" on storage.objects for update to authenticated
  using (bucket_id = 'zine-photos'
         and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'zine-photos'
              and (storage.foldername(name))[1] = auth.uid()::text
              and exists (select 1 from public.zines z
                          where z.id::text = (storage.foldername(name))[2]
                            and z.owner = auth.uid()
                            and z.expires_at > now()));

create policy "zine photos: delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'zine-photos'
         and (storage.foldername(name))[1] = auth.uid()::text);
