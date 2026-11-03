-- TEST DATA ONLY (not part of the template). Runs after all migrations: the departments, job roles, holidays and
-- leave-approver setting that the original company had, so the functional tests can exercise every rule against
-- realistic data. A real company creates all of this in the app instead.

insert into public.departments (name)
select v from (values ('Advertising'), ('Account Managers'), ('Production'), ('Copywriting'), ('Design')) as t(v)
where not exists (select 1 from public.departments d where lower(d.name) = lower(t.v));

insert into public.job_roles (department_id, name)
select d.id, r.name
from public.departments d
cross join (values ('Montage'), ('Operator'), ('Motion Designer')) as r(name)
where lower(d.name) = 'production'
  and not exists (select 1 from public.job_roles j where j.department_id = d.id and lower(j.name) = lower(r.name));

alter table public.public_holidays disable trigger public_holidays_audit_trg;
do $$
declare y int;
begin
  for y in 2025..2040 loop
    perform public.seed_georgian_holidays(y);
  end loop;
end $$;
alter table public.public_holidays enable trigger public_holidays_audit_trg;

update public.departments set approves_all_leaves = true where lower(name) = 'account managers';
