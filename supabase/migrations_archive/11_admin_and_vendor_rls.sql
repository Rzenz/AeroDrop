-- 11_admin_and_vendor_rls.sql
-- RLS policies for admin management, users/vendors, drones, and telemetry.

begin;

-- =========================================================
-- ADMIN ROLE HELPER
-- =========================================================

create or replace function public.is_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.users u
    where u.id = p_user_id
      and lower(u.role) = 'admin'
      and (u.account_status = 'active' or u.account_status is null)
  );
$$;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_admin(uuid) to service_role;

-- =========================================================
-- ENABLE ROW LEVEL SECURITY
-- =========================================================

alter table public.users enable row level security;
alter table public.drones enable row level security;
alter table public.drone_telemetry enable row level security;

-- =========================================================
-- USERS & VENDORS (Consolidated on public.users)
-- =========================================================

-- Active admins can manage any user or vendor profile.
drop policy if exists admin_manage_users
on public.users;

create policy admin_manage_users
on public.users
for all
to authenticated
using (
  public.is_admin(auth.uid())
)
with check (
  public.is_admin(auth.uid())
);

-- =========================================================
-- DRONES
-- =========================================================

-- Authenticated users may read drone status and battery.
drop policy if exists select_drones
on public.drones;

create policy select_drones
on public.drones
for select
to authenticated
using (true);

-- Only active admins may directly update drone records.
drop policy if exists update_drones
on public.drones;

create policy update_drones
on public.drones
for update
to authenticated
using (
  public.is_admin(auth.uid())
)
with check (
  public.is_admin(auth.uid())
);

-- =========================================================
-- DRONE TELEMETRY
-- =========================================================

-- Telemetry can be read by:
-- 1. An active administrator
-- 2. The user who placed the order
-- 3. The vendor assigned to the order (orders.vendor_id = auth.uid())
drop policy if exists select_drone_telemetry
on public.drone_telemetry;

create policy select_drone_telemetry
on public.drone_telemetry
for select
to authenticated
using (
  public.is_admin(auth.uid())
  or exists (
    select 1
    from public.deliveries d
    join public.orders o
      on o.id = d.order_id
    where d.id = drone_telemetry.delivery_id
      and (
        o.user_id = auth.uid()
        or o.vendor_id = auth.uid()
      )
  )
);

commit;

notify pgrst, 'reload schema';