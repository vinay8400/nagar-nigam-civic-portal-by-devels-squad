-- Repair profile creation for all Supabase Auth providers, including Google OAuth.
-- Safe to run repeatedly. Existing profile rows and roles are left unchanged.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(
      nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(new.raw_user_meta_data ->> 'name'), '')
    ),
    'citizen'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill only missing rows. Existing profiles (including admin roles) are not changed.
insert into public.profiles (id, full_name, role)
select
  u.id,
  coalesce(
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'name'), '')
  ),
  'citizen'
from auth.users as u
where not exists (
  select 1
  from public.profiles as p
  where p.id = u.id
)
on conflict (id) do nothing;

commit;
