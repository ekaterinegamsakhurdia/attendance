-- =====================================================================
-- Attendance System, migration 0: the base tables
--
--   The five tables every other migration builds on. Run first, on a new Supabase project (`supabase db push`
--   applies the migrations in file-name order, so this one comes first by itself).
--
--     departments      teams (names are created in the app: Structure tab)
--     employees        one row per person; auth_user_id links to Supabase Auth
--     attendance       one row per clock-in
--     audit_logs       who did what (readable by CEOs and developers only, see later migrations)
--     company_settings one row (id = 1): company name, working hours, time zone
--
--   Row-level security, permissions and every function come from the next migrations. Nothing here is
--   company-specific: the company name and time zone are changed in the app (Settings).
--
-- Safe to run more than once.
-- =====================================================================

create table if not exists public.departments (
  id uuid not null default gen_random_uuid(),
  name text not null unique,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint departments_pkey primary key (id)
);

create table if not exists public.employees (
  id uuid not null default gen_random_uuid(),
  auth_user_id uuid unique,
  employee_number text not null unique,
  first_name text not null,
  last_name text not null,
  email text unique,
  department_id uuid,
  role text not null default 'employee'::text check (role = any (array['employee'::text, 'ceo'::text])),
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint employees_pkey primary key (id),
  constraint employees_auth_user_id_fkey foreign key (auth_user_id) references auth.users(id),
  constraint employees_department_id_fkey foreign key (department_id) references public.departments(id)
);

create table if not exists public.attendance (
  id uuid not null default gen_random_uuid(),
  employee_id uuid,
  work_date date not null,
  clock_in timestamp with time zone not null,
  clock_out timestamp with time zone,
  clock_in_ip inet,
  clock_out_ip inet,
  clockout_type text check (clockout_type = any (array['manual'::text, 'automatic'::text])),
  worked_minutes integer check (worked_minutes is null or worked_minutes >= 0),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint attendance_pkey primary key (id),
  constraint attendance_employee_id_fkey foreign key (employee_id) references public.employees(id)
);

create table if not exists public.audit_logs (
  id uuid not null default gen_random_uuid(),
  actor_user_id uuid,
  employee_id uuid,
  action text not null,
  description text,
  ip_address inet,
  metadata jsonb,
  created_at timestamp with time zone not null default now(),
  constraint audit_logs_pkey primary key (id),
  constraint audit_logs_actor_user_id_fkey foreign key (actor_user_id) references auth.users(id),
  constraint audit_logs_employee_id_fkey foreign key (employee_id) references public.employees(id)
);

create table if not exists public.company_settings (
  id integer not null default 1 check (id = 1),
  company_name text not null default 'Your Company'::text,
  work_start_time time without time zone not null default '09:00:00'::time without time zone,
  work_end_time time without time zone not null default '18:00:00'::time without time zone,
  timezone text not null default 'UTC'::text,
  company_public_ip inet,
  updated_at timestamp with time zone not null default now(),
  constraint company_settings_pkey primary key (id)
);
