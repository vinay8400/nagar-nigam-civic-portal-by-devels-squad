-- Nagar Nigam civic portal schema. Run in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'citizen' check (role in ('citizen','admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.complaints (
  id uuid primary key default gen_random_uuid(),
  complaint_number text unique default ('NN-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null,
  category text not null default 'other',
  address text not null,
  description text,
  latitude double precision,
  longitude double precision,
  photo_url text,
  status text not null default 'लंबित' check (status in ('लंबित','प्रक्रिया में','समाधान हुई')),
  resolution_photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.complaints add column if not exists resolution_photo_url text;
alter table public.complaints add column if not exists updated_at timestamptz not null default now();

alter table public.profiles enable row level security;
alter table public.complaints enable row level security;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.complaints to authenticated;

drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can create their own citizen profile" on public.profiles;
drop policy if exists "Users can update their own profile name" on public.profiles;
create policy "Users can read their own profile" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "Users can create their own citizen profile" on public.profiles
  for insert to authenticated with check (id = auth.uid() and role = 'citizen');
create policy "Users can update their own profile name" on public.profiles
  for update to authenticated using (id = auth.uid())
  with check (id = auth.uid() and role = 'citizen');

drop policy if exists "Citizens read own complaints" on public.complaints;
drop policy if exists "Citizens create own complaints" on public.complaints;
drop policy if exists "Citizens can update no complaint fields" on public.complaints;
drop policy if exists "Admins read all complaints" on public.complaints;
drop policy if exists "Admins update complaints" on public.complaints;
create policy "Citizens read own complaints" on public.complaints
  for select to authenticated using (user_id = auth.uid());
create policy "Admins read all complaints" on public.complaints
  for select to authenticated using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "Citizens create own complaints" on public.complaints
  for insert to authenticated with check (
    user_id = auth.uid()
    and status = 'लंबित'
    and resolution_photo_url is null
  );
create policy "Admins update complaints" on public.complaints
  for update to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
    and (status <> 'समाधान हुई' or resolution_photo_url is not null)
  );

create or replace function public.set_complaint_updated_at()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists complaints_set_updated_at on public.complaints;
create trigger complaints_set_updated_at before update on public.complaints
  for each row execute function public.set_complaint_updated_at();

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
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
insert into public.profiles (id, full_name, role)
select
  u.id,
  coalesce(
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'name'), '')
  ),
  'citizen'
from auth.users as u
where not exists (select 1 from public.profiles as p where p.id = u.id)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('complaint-photos', 'complaint-photos', false)
on conflict (id) do update set public = false;

drop policy if exists "Complaint owners and admins read complaint photos" on storage.objects;
drop policy if exists "Complaint owners upload complaint photos" on storage.objects;
drop policy if exists "Admins upload resolution photos" on storage.objects;
drop policy if exists "Complaint photos: owner and admin read" on storage.objects;
drop policy if exists "Complaint photos: owner upload" on storage.objects;
drop policy if exists "Complaint photos: admin upload" on storage.objects;
create policy "Complaint photos: owner and admin read" on storage.objects
  for select to authenticated using (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and (
      (storage.foldername(name))[2] = auth.uid()::text
      or exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and p.role = 'admin'
      )
    )
  );
create policy "Complaint photos: owner upload" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
create policy "Complaint photos: admin upload" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
