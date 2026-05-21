alter table public.profiles
add column if not exists role text;

update public.profiles
set role = 'member'
where role is null
   or btrim(role) = '';

alter table public.profiles
alter column role set default 'member';

alter table public.profiles
alter column role set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_role_check'
  ) then
    alter table public.profiles
    add constraint profiles_role_check
    check (role in ('member', 'admin'));
  end if;
end $$;

update public.profiles p
set role = 'admin'
from auth.users u
where u.id = p.id
  and lower(u.email) = 'santechjp@hotmail.com';
