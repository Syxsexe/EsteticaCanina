-- Una foto por mascota, solo para la estética.
--
-- La app convierte la imagen a WebP antes de subirla. Aun así, el bucket
-- solo acepta `image/webp`: si alguien se salta la app, Supabase rechaza
-- cualquier otro formato.

-- La ruta del objeto en `fotos-mascotas`: `<mascota_id>/<marca>.webp`. El
-- tutor puede leer esta columna (ve sus mascotas), pero no el objeto: el
-- bucket es privado.
alter table public.mascotas
  add column if not exists foto_path text;

-- ===========================================================================
-- El bucket
-- ===========================================================================
--
-- Privado, solo WebP, máximo 2 MB. Una foto de 1280 px en WebP ronda los
-- 100-300 KB.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos-mascotas', 'fotos-mascotas', false, 2097152, array['image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ===========================================================================
-- Quién puede tocarlo: solo la estética
-- ===========================================================================
--
-- Sin políticas para clientes ni para `anon`: no leen, no suben, no borran.

create policy "la estética ve las fotos de mascotas"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'fotos-mascotas' and public.es_admin());

create policy "la estética sube fotos de mascotas"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'fotos-mascotas' and public.es_admin());

create policy "la estética cambia fotos de mascotas"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'fotos-mascotas' and public.es_admin())
  with check (bucket_id = 'fotos-mascotas' and public.es_admin());

create policy "la estética borra fotos de mascotas"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'fotos-mascotas' and public.es_admin());
