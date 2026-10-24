-- Allow anonymous visitors to read only already-resolved complaint metadata and images.
-- This keeps the rest of the database protected by RLS and does not make the bucket public.

begin;

drop policy if exists "Public can view resolved complaints" on public.complaints;
create policy "Public can view resolved complaints" on public.complaints
  for select to anon
  using (
    status = 'समाधान हुई'
    and resolution_photo_url is not null
  );

drop policy if exists "Public can read resolved complaint images" on storage.objects;
create policy "Public can read resolved complaint images" on storage.objects
  for select to anon
  using (
    bucket_id = 'complaint-photos'
    and (
      exists (
        select 1
        from public.complaints as c
        where c.status = 'समाधान हुई'
          and c.photo_url = name
      )
      or exists (
        select 1
        from public.complaints as c
        where c.status = 'समाधान हुई'
          and c.resolution_photo_url = name
      )
    )
  );

commit;
