alter table public.user_profiles
  add column if not exists birthday date null;

grant select, insert, update on public.user_profiles to authenticated;

alter table public.user_profiles enable row level security;
