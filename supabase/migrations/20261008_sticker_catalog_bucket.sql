-- Private bucket for the Pakistani culture sticker catalog (content/sticker-catalog/v1).
-- Upload the whole v1/ folder into this bucket, keeping the folder names.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'stiksy_bucket',
  'stiksy_bucket',
  false,
  204800, -- 200 KiB; the largest file is a 100 KiB sticker
  array['application/json', 'image/webp', 'image/png']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Signed-in users (including anonymous device sessions) may read, never write.
-- No insert/update/delete policies exist, so only the dashboard/service role can upload.
drop policy if exists "sticker catalog read" on storage.objects;
create policy "sticker catalog read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'stiksy_bucket');
