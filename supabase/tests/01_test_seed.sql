-- TEST DATA ONLY (not part of the template). Runs right after the base migration, before the others.
-- A company row with working hours and a time zone that the tests rely on.
insert into public.company_settings (id, company_name, work_start_time, work_end_time, timezone) values (1, 'Test Company', '11:00', '19:00', 'Asia/Tbilisi') on conflict (id) do nothing;

-- A permissive "legacy" policy the migration must wipe out
alter table public.attendance enable row level security;
create policy legacy_all on public.attendance for all to authenticated using (true) with check (true);

-- Seed: one CEO, two employees (one with pre-existing history)
insert into auth.users (id, email) values
 ('00000000-0000-0000-0000-0000000000c1','ceo@x.test'),
 ('00000000-0000-0000-0000-0000000000a1','alice@x.test'),
 ('00000000-0000-0000-0000-0000000000b1','bob@x.test');
insert into public.employees (id, auth_user_id, employee_number, first_name, last_name, email, role) values
 ('10000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000c1','EMP001','Cee','Oh','ceo@x.test','ceo'),
 ('10000000-0000-0000-0000-0000000000a1','00000000-0000-0000-0000-0000000000a1','EMP002','Alice','A','alice@x.test','employee'),
 ('10000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000b1','EMP003','Bob','B','bob@x.test','employee');
insert into public.attendance (employee_id, work_date, clock_in, clock_out, clockout_type, worked_minutes) values
 ('10000000-0000-0000-0000-0000000000b1', '2026-10-01', '2026-10-01 07:00+00', '2026-10-01 15:00+00', 'manual', 480);

-- Legacy function with a different return type, as found in the real project:
-- the migrations must be able to replace it (CREATE OR REPLACE cannot change a return type).
create or replace function public.auto_clock_out() returns void language sql as $$ select 1 $$;
