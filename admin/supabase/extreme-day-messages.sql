create table if not exists public.stats_extreme_day_messages (
  id uuid primary key,
  scope text not null check (scope in ('global', 'user')),
  user_id uuid null references auth.users(id) on delete cascade,
  trigger_type text not null check (trigger_type in ('max_profit_day', 'max_loss_day')),
  message text not null check (char_length(message) between 1 and 80),
  is_enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stats_extreme_day_messages_scope_user_check check (
    (scope = 'global' and user_id is null)
    or (scope = 'user' and user_id is not null)
  )
);

create index if not exists stats_extreme_day_messages_visibility_idx
  on public.stats_extreme_day_messages (scope, user_id, trigger_type, is_enabled, sort_order, created_at desc);

alter table public.stats_extreme_day_messages enable row level security;

grant select on public.stats_extreme_day_messages to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'stats_extreme_day_messages'
      and policyname = 'Users can read visible extreme day messages'
  ) then
    create policy "Users can read visible extreme day messages"
    on public.stats_extreme_day_messages
    for select to authenticated
    using (
      is_enabled = true
      and (
        scope = 'global'
        or user_id = (select auth.uid())
      )
    );
  end if;
end $$;
