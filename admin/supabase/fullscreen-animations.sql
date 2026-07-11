create table if not exists public.stats_fullscreen_animations (
  id uuid primary key,
  scope text not null check (scope in ('global', 'user')),
  user_id uuid null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 32),
  trigger_type text not null default 'max_profit_day' check (trigger_type in ('max_profit_day', 'birthday_home')),
  storage_path text not null,
  content_type text not null default 'application/zip' check (content_type = 'application/zip'),
  file_type text not null default 'lottie' check (file_type = 'lottie'),
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stats_fullscreen_animations_scope_user_check check (
    (scope = 'global' and user_id is null)
    or (scope = 'user' and user_id is not null)
  )
);

create index if not exists stats_fullscreen_animations_visibility_idx
  on public.stats_fullscreen_animations (scope, user_id, is_enabled, created_at desc);

create index if not exists stats_fullscreen_animations_trigger_visibility_idx
  on public.stats_fullscreen_animations (trigger_type, scope, user_id, is_enabled, created_at desc);

do $$
begin
  alter table public.stats_fullscreen_animations
    drop constraint if exists stats_fullscreen_animations_trigger_type_check;

  alter table public.stats_fullscreen_animations
    add constraint stats_fullscreen_animations_trigger_type_check
    check (trigger_type in ('max_profit_day', 'birthday_home'));
end
$$;

alter table public.stats_fullscreen_animations enable row level security;

grant select on public.stats_fullscreen_animations to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'stats_fullscreen_animations'
      and policyname = 'Users can read visible fullscreen animations'
  ) then
    create policy "Users can read visible fullscreen animations"
    on public.stats_fullscreen_animations
    for select to authenticated
    using (
      is_enabled = true
      and (
        scope = 'global'
        or user_id = (select auth.uid())
      )
    );
  end if;
end
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stats-fullscreen-animations',
  'stats-fullscreen-animations',
  false,
  15728640,
  array['application/zip', 'application/octet-stream']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can read visible fullscreen animation files'
  ) then
    create policy "Users can read visible fullscreen animation files"
    on storage.objects
    for select to authenticated
    using (
      bucket_id = 'stats-fullscreen-animations'
      and (
        name like 'global/%'
        or name like ((select auth.uid())::text || '/%')
      )
    );
  end if;
end
$$;
