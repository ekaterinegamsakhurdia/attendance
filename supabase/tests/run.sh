#!/usr/bin/env bash
# Usage: PGHOST=... PGPORT=... PGUSER=postgres ./run.sh   (needs a scratch Postgres 15+; never run against production)
set -euo pipefail
cd "$(dirname "$0")"
DB=attendance_test
psql -v ON_ERROR_STOP=1 -qc "drop database if exists $DB" -d postgres
psql -v ON_ERROR_STOP=1 -qc "create database $DB" -d postgres
psql -v ON_ERROR_STOP=1 -q -d $DB -f 00_bootstrap.sql
# 1) the base tables, 2) test-only rows that exist before the other migrations (a legacy policy, the first people),
# 3) every other migration, 4) test-only company data (departments, roles, holidays)
first=true
for m in ../migrations/*.sql; do
  echo "applying $m"
  psql -v ON_ERROR_STOP=1 -q -d $DB -f "$m"
  if $first; then psql -v ON_ERROR_STOP=1 -q -d $DB -f 01_test_seed.sql; first=false; fi
done
# A fresh install must carry no company data: no departments, job roles or holidays, and the default floor plan
psql -v ON_ERROR_STOP=1 -q -d $DB <<'SQL'
do $$ begin
  if exists (select 1 from public.departments) then raise exception 'a fresh install must have no departments'; end if;
  if exists (select 1 from public.job_roles) then raise exception 'a fresh install must have no job roles'; end if;
  if exists (select 1 from public.public_holidays) then raise exception 'a fresh install must have no public holidays'; end if;
  if (select count(*) from public.office_rooms) <> 3 then raise exception 'a fresh install has the 3-room default floor plan'; end if;
end $$;
SQL
echo "FRESH INSTALL IS EMPTY OK"
psql -v ON_ERROR_STOP=1 -q -d $DB -f 98_test_company_data.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 02_tests.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 03_tests_org_network_biometric.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 04_tests_developer.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 05_tests_leadership.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 06_tests_leaves.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 07_tests_profiles.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 08_tests_audit_scope.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 09_tests_self_profile.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 10_tests_online_overtime.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 11_tests_office_today.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 12_tests_leave_imported.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 13_tests_bulk_leave_delete.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 14_tests_leave_approver_all.sql
psql -v ON_ERROR_STOP=1 -q -d $DB -f 15_tests_office_rooms.sql

# First-developer script: promotes a normal login, refuses to consume the only CEO
psql -v ON_ERROR_STOP=1 -q -d $DB -c "insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000f9','first.dev@x.test')"
sed "s/you@example.com/first.dev@x.test/; s/'Your'/'First'/; s/'Name'/'Dev'/; s/'DEV001'/'DEV777'/" ../tools/create_first_developer.sql | psql -v ON_ERROR_STOP=1 -q -d $DB
test "$(psql -d $DB -Atc "select role from public.employees where email='first.dev@x.test'")" = developer
if sed "s/you@example.com/ceo@x.test/" ../tools/create_first_developer.sql | psql -v ON_ERROR_STOP=1 -q -d $DB 2>/dev/null; then
  echo "first-developer script consumed the only CEO" >&2; exit 1
fi
if sed "s/you@example.com/nobody@x.test/" ../tools/create_first_developer.sql | psql -v ON_ERROR_STOP=1 -q -d $DB 2>/dev/null; then
  echo "first-developer script accepted a missing login" >&2; exit 1
fi
echo "FIRST DEVELOPER SCRIPT OK"
