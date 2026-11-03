-- =====================================================================
-- Attendance System, migration 15: the office floor plan, editable by a developer
--
--   office_rooms: one row per room of the "Office today" map. A room sits on a 12-column grid (x, y = top-left
--   cell, w, h = size in cells; one row is 56 px on a wide screen) and holds the people of the departments
--   listed in department_ids, the CEO in a given seat (seat 1 = the CEO with the lowest employee number, and so
--   on) and, when everyone_else is on, every person whose department has no room of its own (so a department
--   created later still shows up on the map). A room with none of these is a plain room (a meeting room, a
--   kitchen). Rooms may not overlap and may not leave the 12 x 40 floor; a department is in one room only; a CEO
--   seat in one room only; only one room is "everyone else".
--
--   Everybody signed in can read the plan. Nobody can write to the table directly:
--     dev_save_office_layout(rooms)   developer only. Replaces the whole plan in one go, so a half-finished
--                                     plan can never be saved. Audited ("office.layout", old and new plan).
--     dev_reset_office_layout()       developer only. Restores the default plan: one open office for everybody
--                                     and a room each for CEO 1 and CEO 2. Audited.
--   The plan is cleared with TRUNCATE, not DELETE: Supabase refuses a DELETE without a WHERE clause.
--   If that guard ever fires inside one of these functions, the error says which statement caused it.
--
--   office_today() is not touched: it already returns the department and the CEO seat.
--
-- Safe to run more than once.
-- =====================================================================

begin;

create table if not exists public.office_rooms (
  id             uuid primary key default gen_random_uuid(),
  name           text     not null check (char_length(btrim(name)) between 1 and 40),
  x              smallint not null check (x between 0 and 11),
  y              smallint not null check (y between 0 and 39),
  w              smallint not null check (w between 1 and 12),
  h              smallint not null check (h between 1 and 40),
  department_ids uuid[]   not null default '{}',
  ceo_seat       smallint check (ceo_seat between 1 and 9),
  everyone_else  boolean  not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint office_rooms_inside_x check (x + w <= 12),
  constraint office_rooms_inside_y check (y + h <= 40),
  -- rooms never overlap (cells are inclusive, so neighbours that only touch are fine)
  constraint office_rooms_no_overlap exclude using gist
    (box(point(x, y), point(x + w - 1, y + h - 1)) with &&)
);

create unique index if not exists office_rooms_ceo_seat_key on public.office_rooms (ceo_seat) where ceo_seat is not null;
create unique index if not exists office_rooms_everyone_else_key on public.office_rooms (everyone_else) where everyone_else;

drop trigger if exists office_rooms_updated_at on public.office_rooms;
create trigger office_rooms_updated_at before update on public.office_rooms
  for each row execute function public.set_updated_at();

alter table public.office_rooms enable row level security;
drop policy if exists office_rooms_select on public.office_rooms;
create policy office_rooms_select on public.office_rooms
  for select to authenticated using (public.current_employee_id() is not null);

revoke all on public.office_rooms from public, anon;
revoke insert, update, delete, truncate on public.office_rooms from authenticated;
grant select on public.office_rooms to authenticated;

-- ---------------------------------------------------------------------
-- The default plan (internal: used by the first run and by dev_reset_office_layout)
-- ---------------------------------------------------------------------
create or replace function public.office_apply_default_layout()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  truncate public.office_rooms;  -- not a DELETE, so Supabase's "DELETE requires a WHERE clause" guard never applies
  insert into public.office_rooms (name, x, y, w, h, department_ids, ceo_seat, everyone_else) values
    ('Open office', 0, 0, 8, 6, '{}', null, true),
    ('CEO 1',       8, 0, 4, 3, '{}', 1,    false),
    ('CEO 2',       8, 3, 4, 3, '{}', 2,    false);
end;
$$;

revoke all on function public.office_apply_default_layout() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from public.office_rooms) then
    perform public.office_apply_default_layout();
  end if;
end $$;

-- A deleted department leaves its room (the room itself stays).
create or replace function public.office_rooms_forget_department()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.office_rooms set department_ids = array_remove(department_ids, old.id)
  where department_ids @> array[old.id];
  return old;
end;
$$;
revoke all on function public.office_rooms_forget_department() from public, anon, authenticated;

drop trigger if exists departments_forget_in_office on public.departments;
create trigger departments_forget_in_office after delete on public.departments
  for each row execute function public.office_rooms_forget_department();

-- ---------------------------------------------------------------------
-- Developer: save the whole plan, and go back to the default plan
-- ---------------------------------------------------------------------

create or replace function public.dev_save_office_layout(p_rooms jsonb)
returns setof public.office_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx text;
  r record;
  o record;
  before_rooms jsonb;
  n integer;
begin
  if not public.is_developer() then
    raise exception 'Only a developer can do this.' using errcode = '42501';
  end if;
  if p_rooms is null or jsonb_typeof(p_rooms) <> 'array' then
    raise exception 'Send the rooms as a list.' using errcode = '22023';
  end if;
  n := jsonb_array_length(p_rooms);
  if n > 40 then
    raise exception 'A floor plan can have at most 40 rooms.' using errcode = '22023';
  end if;

  create temporary table if not exists pg_temp.incoming_rooms (
    id uuid, name text, x integer, y integer, w integer, h integer, department_ids uuid[], ceo_seat integer, everyone_else boolean
  ) on commit drop;
  truncate pg_temp.incoming_rooms;

  insert into pg_temp.incoming_rooms
  select t.id, btrim(t.name), t.x, t.y, t.w, t.h, coalesce(t.department_ids, '{}'), t.ceo_seat, coalesce(t.everyone_else, false)
  from jsonb_to_recordset(p_rooms) as t(id uuid, name text, x integer, y integer, w integer, h integer, department_ids uuid[], ceo_seat integer, everyone_else boolean);

  for r in select * from pg_temp.incoming_rooms loop
    if r.name is null or char_length(r.name) = 0 then
      raise exception 'Every room needs a name.' using errcode = '22023';
    end if;
    if char_length(r.name) > 40 then
      raise exception 'The room name "%" is longer than 40 characters.', left(r.name, 20) using errcode = '22023';
    end if;
    if r.x is null or r.y is null or r.w is null or r.h is null
       or r.x < 0 or r.y < 0 or r.w < 1 or r.h < 1 or r.x + r.w > 12 or r.y + r.h > 40 then
      raise exception '"%" does not fit on the floor (12 columns, 40 rows).', r.name using errcode = '22023';
    end if;
    if r.ceo_seat is not null and r.ceo_seat not between 1 and 9 then
      raise exception 'CEO seat must be between 1 and 9.' using errcode = '22023';
    end if;
  end loop;

  if (select count(distinct id) from pg_temp.incoming_rooms where id is not null)
     <> (select count(id) from pg_temp.incoming_rooms) then
    raise exception 'The same room was sent twice.' using errcode = '22023';
  end if;

  if exists (
    select 1 from pg_temp.incoming_rooms i, unnest(i.department_ids) as did
    where not exists (select 1 from public.departments d where d.id = did)
  ) then
    raise exception 'A department in the plan no longer exists. Reload and try again.' using errcode = '22023';
  end if;

  select i1.name as a, i2.name as b into o
  from pg_temp.incoming_rooms i1
  join pg_temp.incoming_rooms i2
    on i1.ctid < i2.ctid and i1.department_ids && i2.department_ids
  limit 1;
  if found then
    raise exception 'A department cannot be in two rooms ("%" and "%").', o.a, o.b using errcode = '22023';
  end if;

  select i1.name as a, i2.name as b into o
  from pg_temp.incoming_rooms i1
  join pg_temp.incoming_rooms i2
    on i1.ctid < i2.ctid and i1.ceo_seat is not null and i1.ceo_seat = i2.ceo_seat
  limit 1;
  if found then
    raise exception 'A CEO seat cannot be in two rooms ("%" and "%").', o.a, o.b using errcode = '22023';
  end if;

  select i1.name as a, i2.name as b into o
  from pg_temp.incoming_rooms i1
  join pg_temp.incoming_rooms i2
    on i1.ctid < i2.ctid and i1.everyone_else and i2.everyone_else
  limit 1;
  if found then
    raise exception 'Only one room can be for everybody else ("%" and "%").', o.a, o.b using errcode = '22023';
  end if;

  select i1.name as a, i2.name as b into o
  from pg_temp.incoming_rooms i1
  join pg_temp.incoming_rooms i2
    on i1.ctid < i2.ctid
   and i1.x < i2.x + i2.w and i2.x < i1.x + i1.w
   and i1.y < i2.y + i2.h and i2.y < i1.y + i1.h
  limit 1;
  if found then
    raise exception 'The rooms "%" and "%" overlap.', o.a, o.b using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.y, x.x), '[]'::jsonb) into before_rooms
  from (select id, name, x, y, w, h, department_ids, ceo_seat, everyone_else from public.office_rooms) x;

  truncate public.office_rooms;  -- not a DELETE, so Supabase's "DELETE requires a WHERE clause" guard never applies
  insert into public.office_rooms (id, name, x, y, w, h, department_ids, ceo_seat, everyone_else)
  select coalesce(i.id, gen_random_uuid()), i.name, i.x, i.y, i.w, i.h, i.department_ids, i.ceo_seat, i.everyone_else
  from pg_temp.incoming_rooms i;

  perform public.log_audit('office.layout', null,
    'Developer changed the office floor plan (' || n || case when n = 1 then ' room)' else ' rooms)' end,
    jsonb_build_object('old', before_rooms, 'new', p_rooms));

  return query select * from public.office_rooms order by y, x, name;
exception
  when cardinality_violation then
    -- Supabase's "DELETE/UPDATE requires a WHERE clause" guard: say which statement caused it
    get stacked diagnostics ctx = pg_exception_context;
    raise exception '% (where: %)', sqlerrm, replace(ctx, E'\n', ' | ') using errcode = '21000';
end;
$$;

revoke all on function public.dev_save_office_layout(jsonb) from public, anon;
grant execute on function public.dev_save_office_layout(jsonb) to authenticated;

create or replace function public.dev_reset_office_layout()
returns setof public.office_rooms
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx text;
  before_rooms jsonb;
begin
  if not public.is_developer() then
    raise exception 'Only a developer can do this.' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(x) order by x.y, x.x), '[]'::jsonb) into before_rooms
  from (select id, name, x, y, w, h, department_ids, ceo_seat, everyone_else from public.office_rooms) x;

  perform public.office_apply_default_layout();

  perform public.log_audit('office.layout_reset', null,
    'Developer restored the original office floor plan', jsonb_build_object('old', before_rooms));

  return query select * from public.office_rooms order by y, x, name;
exception
  when cardinality_violation then
    -- Supabase's "DELETE/UPDATE requires a WHERE clause" guard: say which statement caused it
    get stacked diagnostics ctx = pg_exception_context;
    raise exception '% (where: %)', sqlerrm, replace(ctx, E'\n', ' | ') using errcode = '21000';
end;
$$;

revoke all on function public.dev_reset_office_layout() from public, anon;
grant execute on function public.dev_reset_office_layout() to authenticated;

commit;
