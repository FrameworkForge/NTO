-- NTO contract v1. Cloud records never contain local Mac filesystem paths.
create table public.projects (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (length(trim(title)) > 0), created_at timestamptz not null default now(), unique (id, owner_id)
);
create table public.assets (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 filename text not null, media_type text not null, original_object_key text,
 width integer not null check(width>0), height integer not null check(height>0),
 rating integer not null default 0 check(rating between 0 and 5), flag text not null default 'none' check(flag in ('none','pick','reject')),
 favourite boolean not null default false, unique(id,owner_id),
 check(original_object_key is null or (original_object_key like owner_id::text || '/%' and original_object_key not like '%..%'))
);
create table public.project_assets (
 project_id uuid not null, asset_id uuid not null, owner_id uuid not null references auth.users(id) on delete cascade,
 primary key(project_id,asset_id), foreign key(project_id,owner_id) references public.projects(id,owner_id) on delete cascade,
 foreign key(asset_id,owner_id) references public.assets(id,owner_id) on delete cascade
);
create table public.collections (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade, project_id uuid not null,
 title text not null check(length(trim(title))>0), unique(id,owner_id), foreign key(project_id,owner_id) references public.projects(id,owner_id) on delete cascade
);
create table public.collection_assets (
 collection_id uuid not null, asset_id uuid not null, owner_id uuid not null references auth.users(id) on delete cascade,
 position integer not null default 0 check(position>=0), primary key(collection_id,asset_id),
 foreign key(collection_id,owner_id) references public.collections(id,owner_id) on delete cascade,
 foreign key(asset_id,owner_id) references public.assets(id,owner_id) on delete cascade
);
create table public.edit_recipes (
 asset_id uuid not null, owner_id uuid not null references auth.users(id) on delete cascade,
 schema_version integer not null default 1 check(schema_version=1), revision integer not null check(revision>0),
 recipe jsonb not null check (jsonb_typeof(recipe)='object' and recipe @> '{"schemaVersion":1}'::jsonb),
 primary key(asset_id,revision), foreign key(asset_id,owner_id) references public.assets(id,owner_id) on delete cascade,
 check((recipe->>'assetId')::uuid=asset_id and (recipe->>'revision')::integer=revision)
);
create table public.renditions (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade, asset_id uuid not null,
 recipe_revision integer not null, kind text not null check(kind in ('thumbnail','preview','web','master','export')),
 object_key text not null, width integer not null check(width>0), height integer not null check(height>0), content_key text not null,
 unique(id,owner_id), foreign key(asset_id,owner_id) references public.assets(id,owner_id) on delete cascade,
 foreign key(asset_id,recipe_revision) references public.edit_recipes(asset_id,revision),
 check(object_key like owner_id::text || '/%' and object_key not like '%..%')
);
create table public.publications (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade, project_id uuid not null,
 destination text not null check(destination in ('gallery','portfolio')), title text not null check(length(trim(title))>0), slug text not null,
 status text not null default 'draft' check(status in ('draft','published')), visibility text not null default 'unlisted' check(visibility in ('public','unlisted','password')),
 downloads text not null default 'none' check(downloads in ('none','web','master')), cover_asset_id uuid,
 revision integer not null default 1 check(revision>0), unique(id,owner_id), unique(owner_id,destination,slug),
 foreign key(project_id,owner_id) references public.projects(id,owner_id) on delete cascade,
 foreign key(cover_asset_id,owner_id) references public.assets(id,owner_id)
);
create table public.publication_assets (
 publication_id uuid not null, asset_id uuid not null, owner_id uuid not null references auth.users(id) on delete cascade,
 position integer not null check(position>=0), primary key(publication_id,asset_id), unique(publication_id,position),
 foreign key(publication_id,owner_id) references public.publications(id,owner_id) on delete cascade,
 foreign key(asset_id,owner_id) references public.assets(id,owner_id) on delete cascade
);
create function public.protect_original_identity() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.id <> old.id or new.owner_id <> old.owner_id or (old.original_object_key is not null and new.original_object_key is distinct from old.original_object_key) then
  raise exception 'Original identity is immutable';
 end if;
 return new;
end; $$;
create trigger immutable_original before update on public.assets for each row execute function public.protect_original_identity();

alter table public.projects enable row level security;
create policy owner_access on public.projects for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.projects to authenticated;
revoke all on public.projects from anon;
create index projects_owner_idx on public.projects(owner_id);

alter table public.assets enable row level security;
create policy owner_access on public.assets for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.assets to authenticated;
revoke all on public.assets from anon;
create index assets_owner_idx on public.assets(owner_id);

alter table public.project_assets enable row level security;
create policy owner_access on public.project_assets for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.project_assets to authenticated;
revoke all on public.project_assets from anon;
create index project_assets_owner_idx on public.project_assets(owner_id);

alter table public.collections enable row level security;
create policy owner_access on public.collections for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.collections to authenticated;
revoke all on public.collections from anon;
create index collections_owner_idx on public.collections(owner_id);

alter table public.collection_assets enable row level security;
create policy owner_access on public.collection_assets for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.collection_assets to authenticated;
revoke all on public.collection_assets from anon;
create index collection_assets_owner_idx on public.collection_assets(owner_id);

alter table public.edit_recipes enable row level security;
create policy owner_access on public.edit_recipes for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.edit_recipes to authenticated;
revoke all on public.edit_recipes from anon;
create index edit_recipes_owner_idx on public.edit_recipes(owner_id);

alter table public.renditions enable row level security;
create policy owner_access on public.renditions for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.renditions to authenticated;
revoke all on public.renditions from anon;
create index renditions_owner_idx on public.renditions(owner_id);

alter table public.publications enable row level security;
create policy owner_access on public.publications for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.publications to authenticated;
revoke all on public.publications from anon;
create index publications_owner_idx on public.publications(owner_id);

alter table public.publication_assets enable row level security;
create policy owner_access on public.publication_assets for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id);
grant select,insert,update,delete on public.publication_assets to authenticated;
revoke all on public.publication_assets from anon;
create index publication_assets_owner_idx on public.publication_assets(owner_id);

insert into storage.buckets(id,name,public) values ('originals','originals',false),('renditions','renditions',false);
create policy owner_read_files on storage.objects for select to authenticated
 using (bucket_id in ('originals','renditions') and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy owner_insert_files on storage.objects for insert to authenticated
 with check (bucket_id in ('originals','renditions') and (storage.foldername(name))[1]=(select auth.uid())::text and name not like '%..%');
-- No client overwrite/delete policy. Originals are immutable; replacement renditions use new keys.
