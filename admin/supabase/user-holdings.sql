create table if not exists public.user_holdings (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_key text not null,
  stock_name text not null check (length(trim(stock_name)) between 1 and 160),
  stock_code text null,
  market_value double precision null,
  quantity double precision null,
  current_price double precision null,
  cost_price double precision null,
  today_pnl double precision null,
  today_pnl_percent double precision null,
  holding_pnl double precision null,
  holding_pnl_percent double precision null,
  data_timestamp timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  unique (user_id, source_key)
);

create index if not exists user_holdings_user_active_idx
  on public.user_holdings (user_id, data_timestamp desc)
  where deleted_at is null;
create index if not exists user_holdings_updated_idx
  on public.user_holdings (user_id, updated_at desc);

alter table public.user_holdings enable row level security;
grant select, insert, update on public.user_holdings to authenticated;

drop policy if exists "Users read own holdings" on public.user_holdings;
create policy "Users read own holdings" on public.user_holdings for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users insert own holdings" on public.user_holdings;
create policy "Users insert own holdings" on public.user_holdings for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users update own holdings" on public.user_holdings;
create policy "Users update own holdings" on public.user_holdings for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
