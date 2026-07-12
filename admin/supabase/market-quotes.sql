alter table public.user_holdings
  add column if not exists quote_session text null,
  add column if not exists quote_at timestamptz null,
  add column if not exists quote_provider text null,
  add column if not exists previous_close double precision null,
  add column if not exists regular_close double precision null,
  add column if not exists session_pnl double precision null,
  add column if not exists session_pnl_percent double precision null,
  add column if not exists quote_is_stale boolean not null default false;

alter table public.user_holdings
  add column if not exists regular_price double precision null,
  add column if not exists regular_pnl double precision null,
  add column if not exists regular_pnl_percent double precision null,
  add column if not exists regular_quote_at timestamptz null,
  add column if not exists regular_provider text null,
  add column if not exists pre_market_price double precision null,
  add column if not exists pre_market_pnl double precision null,
  add column if not exists pre_market_pnl_percent double precision null,
  add column if not exists pre_market_quote_at timestamptz null,
  add column if not exists pre_market_provider text null,
  add column if not exists after_hours_price double precision null,
  add column if not exists after_hours_pnl double precision null,
  add column if not exists after_hours_pnl_percent double precision null,
  add column if not exists after_hours_quote_at timestamptz null,
  add column if not exists after_hours_provider text null,
  add column if not exists overnight_price double precision null,
  add column if not exists overnight_pnl double precision null,
  add column if not exists overnight_pnl_percent double precision null,
  add column if not exists overnight_quote_at timestamptz null,
  add column if not exists overnight_provider text null;

create table if not exists public.market_quote_cache (
  symbol text not null,
  session text not null,
  price double precision not null,
  baseline_price double precision not null,
  previous_close double precision null,
  regular_close double precision null,
  change_amount double precision not null,
  change_percent double precision not null,
  provider text not null,
  quote_at timestamptz not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now(),
  primary key (symbol, session)
);
alter table public.market_quote_cache enable row level security;
revoke all on public.market_quote_cache from anon, authenticated;

create table if not exists public.holding_daily_settlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  trading_date date not null,
  total_market_value double precision not null,
  regular_pnl double precision not null,
  regular_pnl_percent double precision not null,
  holding_count integer not null,
  priced_holding_count integer not null,
  currency text not null default 'USD' check (currency = 'USD'),
  quote_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, trading_date)
);
create index if not exists holding_daily_settlements_user_date_idx
  on public.holding_daily_settlements(user_id, trading_date desc);
alter table public.holding_daily_settlements enable row level security;
grant select on public.holding_daily_settlements to authenticated;
drop policy if exists "Users read own holding settlements" on public.holding_daily_settlements;
create policy "Users read own holding settlements" on public.holding_daily_settlements
  for select to authenticated using ((select auth.uid()) = user_id);

create extension if not exists pg_cron with schema extensions;
create or replace function public.capture_holding_daily_settlements()
returns void language plpgsql security definer set search_path = public as $$
declare ny_now timestamp := now() at time zone 'America/New_York';
begin
  if extract(isodow from ny_now) > 5 or extract(hour from ny_now) <> 16 then return; end if;
  insert into public.holding_daily_settlements
    (user_id, trading_date, total_market_value, regular_pnl, regular_pnl_percent, holding_count, priced_holding_count, quote_at, updated_at)
  select user_id, ny_now::date,
    sum(quantity * regular_close),
    sum(quantity * (regular_close - previous_close)),
    case when sum(quantity * previous_close) > 0 then sum(quantity * (regular_close - previous_close)) / sum(quantity * previous_close) * 100 else 0 end,
    count(*)::int,
    count(*) filter (where quantity is not null and regular_close is not null and previous_close is not null)::int,
    max(quote_at), now()
  from public.user_holdings
  where deleted_at is null and quantity is not null and regular_close is not null and previous_close is not null
  group by user_id
  on conflict (user_id, trading_date) do update set
    total_market_value = excluded.total_market_value, regular_pnl = excluded.regular_pnl,
    regular_pnl_percent = excluded.regular_pnl_percent, holding_count = excluded.holding_count,
    priced_holding_count = excluded.priced_holding_count, quote_at = excluded.quote_at, updated_at = now();
end $$;
revoke all on function public.capture_holding_daily_settlements() from public, anon, authenticated;

do $$ begin
  if not exists (select 1 from cron.job where jobname = 'capture-us-holdings-close-dst') then
    perform cron.schedule('capture-us-holdings-close-dst', '10 20 * * 1-5', 'select public.capture_holding_daily_settlements()');
  end if;
  if not exists (select 1 from cron.job where jobname = 'capture-us-holdings-close-standard') then
    perform cron.schedule('capture-us-holdings-close-standard', '10 21 * * 1-5', 'select public.capture_holding_daily_settlements()');
  end if;
end $$;
