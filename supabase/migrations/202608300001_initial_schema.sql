create extension if not exists pgcrypto;
create schema if not exists private;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('senior','family')),
  first_name text not null, last_name text not null, phone text not null unique,
  family_phone text, connection_code text unique, primary_family_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index profiles_primary_family_idx on public.profiles(primary_family_id);

create table public.care_links (
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.profiles(id) on delete cascade,
  senior_id uuid not null unique references public.profiles(id) on delete cascade,
  relationship text not null, custom_relationship text, connected_at timestamptz not null default now(), unique(family_id,senior_id)
);
create index care_links_family_idx on public.care_links(family_id);

create or replace function private.can_access_senior(target uuid) returns boolean language sql stable security definer set search_path='' as $$
  select (select auth.uid()) = target or exists(select 1 from public.care_links c where c.senior_id=target and c.family_id=(select auth.uid()));
$$;
create or replace function private.is_family_of(target uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.care_links c where c.senior_id=target and c.family_id=(select auth.uid()));
$$;
revoke all on function private.can_access_senior(uuid) from public; revoke all on function private.is_family_of(uuid) from public;
grant execute on function private.can_access_senior(uuid), private.is_family_of(uuid) to authenticated;

create table public.checkins (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 local_date date not null, slot text not null check(slot in ('morning','noon','evening')),
 feeling text not null check(feeling in ('good','okay','not_well')), concern_level text check(concern_level in ('feels_unwell','needs_call','emergency')),
 submitted_at timestamptz not null default now(), acknowledged_at timestamptz, family_message text,
 call_status text check(call_status in ('done','later')), call_at timestamptz, unique(senior_id,local_date,slot)
);
create index checkins_senior_date_idx on public.checkins(senior_id,local_date desc);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), recipient_id uuid not null references public.profiles(id) on delete cascade,
 senior_id uuid references public.profiles(id) on delete cascade, type text not null, title text not null, body text not null,
 entity_type text, entity_id uuid, read_at timestamptz, created_at timestamptz not null default now()
); create index notifications_recipient_idx on public.notifications(recipient_id,created_at desc);

create table public.outings (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 destination text not null, destination_note text, expected_return_at timestamptz not null, left_at timestamptz not null default now(),
 returned_at timestamptz, return_latitude double precision, return_longitude double precision,
 location_request_id uuid, extension_count int not null default 0
); create index outings_senior_idx on public.outings(senior_id,left_at desc);
create table public.location_requests (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null references public.profiles(id) on delete cascade, outing_id uuid not null references public.outings(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','answered','expired')), requested_at timestamptz not null default now()
);
alter table public.outings add constraint outings_location_request_fk foreign key(location_request_id) references public.location_requests(id) on delete set null;
create table public.location_responses (
 id uuid primary key default gen_random_uuid(), request_id uuid not null references public.location_requests(id) on delete cascade,
 senior_id uuid not null references public.profiles(id) on delete cascade, response text not null check(response in ('shared','safe_on_time')),
 latitude double precision, longitude double precision, expires_at timestamptz, created_at timestamptz not null default now()
);
create table public.service_requests (
 id uuid primary key default gen_random_uuid(), outing_id uuid not null references public.outings(id) on delete cascade,
 senior_id uuid not null references public.profiles(id) on delete cascade, status text not null default 'requested' check(status in ('requested','arranged','completed')),
 driver_name text, vehicle text, plate text, eta text, created_at timestamptz not null default now()
);
create table public.emergencies (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 status text not null default 'open' check(status in ('open','closed')), created_at timestamptz not null default now(), closed_at timestamptz, followup_result text
);

create table public.remember_messages (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null references public.profiles(id) on delete cascade, title text not null, body text not null,
 read_at timestamptz, quick_response text check(quick_response in ('understood','call_me')), archived_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
); create index remember_senior_idx on public.remember_messages(senior_id,created_at desc);
create table public.medicines (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 medicine_name text not null, dosage text, times_of_day text[] not null default '{}', days_of_week text[] not null default '{}', is_daily boolean not null default false,
 course_start date, course_end date, notes text, created_at timestamptz not null default now()
);
create table public.health_records (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, record_type text, condition_summary text, symptoms text, diagnosis text, treatment text,
 physician_name text, record_date date, notes text, created_at timestamptz not null default now()
);
create table public.medical_files (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 health_record_id uuid references public.health_records(id) on delete cascade, storage_path text not null, file_name text not null,
 content_type text, created_at timestamptz not null default now()
);
create table public.appointments (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 title text not null, doctor_name text, clinic_name text, starts_at timestamptz not null, notes text,
 reminder_offsets_minutes int[] not null default '{10080,1440,180,60}', completed_at timestamptz, report_prompt_dismissed_at timestamptz,
 created_at timestamptz not null default now()
); create index appointments_senior_time_idx on public.appointments(senior_id,starts_at);
create table public.medical_contacts (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 name text not null, contact_type text, phone text, address text, notes text, created_at timestamptz not null default now()
);
create table public.special_dates (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 occasion text not null, event_date date not null, notes text, reminder_offsets_days int[] not null default '{30,7,1,0}', created_at timestamptz not null default now()
);
create table public.family_notes (
 id uuid primary key default gen_random_uuid(), senior_id uuid not null references public.profiles(id) on delete cascade,
 family_id uuid not null references public.profiles(id) on delete cascade, title text not null, body text not null, remind_at timestamptz,
 completed_at timestamptz, created_at timestamptz not null default now()
);

alter table public.profiles enable row level security; alter table public.care_links enable row level security; alter table public.checkins enable row level security;
alter table public.notifications enable row level security; alter table public.outings enable row level security; alter table public.location_requests enable row level security;
alter table public.location_responses enable row level security; alter table public.service_requests enable row level security; alter table public.emergencies enable row level security;
alter table public.remember_messages enable row level security; alter table public.medicines enable row level security; alter table public.health_records enable row level security;
alter table public.medical_files enable row level security; alter table public.appointments enable row level security; alter table public.medical_contacts enable row level security;
alter table public.special_dates enable row level security; alter table public.family_notes enable row level security;

create policy profiles_read on public.profiles for select to authenticated using(id=(select auth.uid()) or primary_family_id=(select auth.uid()));
create policy profiles_self_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy links_read on public.care_links for select to authenticated using(family_id=(select auth.uid()) or senior_id=(select auth.uid()));
create policy checkins_read on public.checkins for select to authenticated using(private.can_access_senior(senior_id));
create policy checkins_senior_insert on public.checkins for insert to authenticated with check(senior_id=(select auth.uid()));
create policy checkins_family_update on public.checkins for update to authenticated using(private.is_family_of(senior_id)) with check(private.is_family_of(senior_id));
create policy notifications_read on public.notifications for select to authenticated using(recipient_id=(select auth.uid()));
create policy notifications_update on public.notifications for update to authenticated using(recipient_id=(select auth.uid())) with check(recipient_id=(select auth.uid()));
create policy notifications_insert on public.notifications for insert to authenticated with check(recipient_id=(select auth.uid()) or private.can_access_senior(senior_id));
create policy outings_read on public.outings for select to authenticated using(private.can_access_senior(senior_id));
create policy outings_insert on public.outings for insert to authenticated with check(senior_id=(select auth.uid()));
create policy outings_update on public.outings for update to authenticated using(private.can_access_senior(senior_id)) with check(private.can_access_senior(senior_id));
create policy location_requests_all on public.location_requests for all to authenticated using(private.can_access_senior(senior_id)) with check(private.can_access_senior(senior_id));
create policy location_responses_all on public.location_responses for all to authenticated using(private.can_access_senior(senior_id)) with check(private.can_access_senior(senior_id));
create policy service_requests_all on public.service_requests for all to authenticated using(private.can_access_senior(senior_id)) with check(private.can_access_senior(senior_id));
create policy emergencies_read on public.emergencies for select to authenticated using(private.can_access_senior(senior_id));
create policy emergencies_insert on public.emergencies for insert to authenticated with check(senior_id=(select auth.uid()));
create policy emergencies_family_update on public.emergencies for update to authenticated using(private.is_family_of(senior_id)) with check(private.is_family_of(senior_id));
create policy remember_read on public.remember_messages for select to authenticated using(private.can_access_senior(senior_id));
create policy remember_family_insert on public.remember_messages for insert to authenticated with check(family_id=(select auth.uid()) and private.is_family_of(senior_id));
create policy remember_family_update on public.remember_messages for update to authenticated using((family_id=(select auth.uid()) and read_at is null) or senior_id=(select auth.uid())) with check(private.can_access_senior(senior_id));

do $$ declare t text; begin foreach t in array array['medicines','health_records','medical_files','appointments','medical_contacts','special_dates'] loop execute format('create policy %I on public.%I for select to authenticated using(private.can_access_senior(senior_id))',t||'_read',t); execute format('create policy %I on public.%I for insert to authenticated with check(private.is_family_of(senior_id))',t||'_insert',t); execute format('create policy %I on public.%I for update to authenticated using(private.is_family_of(senior_id)) with check(private.is_family_of(senior_id))',t||'_update',t); execute format('create policy %I on public.%I for delete to authenticated using(private.is_family_of(senior_id))',t||'_delete',t); end loop; end $$;
create policy notes_family_all on public.family_notes for all to authenticated using(family_id=(select auth.uid()) and private.is_family_of(senior_id)) with check(family_id=(select auth.uid()) and private.is_family_of(senior_id));

create or replace function private.notify_family() returns trigger language plpgsql security definer set search_path='' as $$ declare fid uuid; begin select primary_family_id into fid from public.profiles where id=new.senior_id; if fid is not null then insert into public.notifications(recipient_id,senior_id,type,title,body,entity_type,entity_id) values(fid,new.senior_id,tg_argv[0],tg_argv[1],tg_argv[2],tg_table_name,new.id); end if; return new; end $$;
revoke all on function private.notify_family() from public;
create trigger checkin_notify after insert on public.checkins for each row execute function private.notify_family('checkin','وضعیت جدید سالمند','سالمند وضعیت خود را ثبت کرد.');
create trigger outing_notify after insert on public.outings for each row execute function private.notify_family('outing','خروج از خانه','سالمند خروج و زمان بازگشت را ثبت کرد.');
create trigger emergency_notify after insert on public.emergencies for each row execute function private.notify_family('emergency','هشدار اضطراری','سالمند درخواست کمک فوری ثبت کرد.');
create trigger service_notify after insert on public.service_requests for each row execute function private.notify_family('service','درخواست خودرو','سالمند درخواست خودرو ثبت کرد.');

insert into storage.buckets(id,name,public) values('medical-files','medical-files',false) on conflict(id) do nothing;
create policy medical_files_storage_read on storage.objects for select to authenticated using(bucket_id='medical-files' and private.can_access_senior((storage.foldername(name))[1]::uuid));
create policy medical_files_storage_insert on storage.objects for insert to authenticated with check(bucket_id='medical-files' and private.is_family_of((storage.foldername(name))[1]::uuid));
create policy medical_files_storage_update on storage.objects for update to authenticated using(bucket_id='medical-files' and private.is_family_of((storage.foldername(name))[1]::uuid)) with check(bucket_id='medical-files' and private.is_family_of((storage.foldername(name))[1]::uuid));
create policy medical_files_storage_delete on storage.objects for delete to authenticated using(bucket_id='medical-files' and private.is_family_of((storage.foldername(name))[1]::uuid));

grant usage on schema public to authenticated; grant select,insert,update,delete on all tables in schema public to authenticated;
