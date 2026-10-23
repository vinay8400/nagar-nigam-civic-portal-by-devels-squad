-- Repair private complaint photo access for paths shaped as:
-- complaints/<user-uuid>/<complaint-uuid>/<filename>
-- Safe to rerun. Does not change the bucket visibility, tables, or complaint data.
begin;

-- Remove the policy names used by the app setup and this migration before recreating them.
drop policy if exists "Complaint owners and admins read complaint photos" on storage.objects;
drop policy if exists "Complaint owners upload complaint photos" on storage.objects;
drop policy if exists "Admins upload resolution photos" on storage.objects;
drop policy if exists "Complaint photos: owner and admin read" on storage.objects;
drop policy if exists "Complaint photos: owner upload" on storage.objects;
drop policy if exists "Complaint photos: admin upload" on storage.objects;

create policy "Complaint photos: owner and admin read" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and (
      (storage.foldername(name))[2] = auth.uid()::text
      or exists (
        select 1
        from public.profiles as p
        where p.id = auth.uid()
          and p.role = 'admin'
      )
    )
  );

create policy "Complaint photos: owner upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

create policy "Complaint photos: admin upload" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'complaint-photos'
    and coalesce(array_length(storage.foldername(name), 1), 0) = 3
    and (storage.foldername(name))[1] = 'complaints'
    and exists (
      select 1
      from public.profiles as p
      where p.id = auth.uid()
        and p.role = 'admin'
    )
  );

commit;
