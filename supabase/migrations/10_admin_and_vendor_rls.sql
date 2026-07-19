-- 10_admin_and_vendor_rls.sql
-- RLS policies for admin management, vendors, drones, and telemetry.

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
    from public.user_credentials uc
    join public.user_roles ur
      on ur.role_id = uc.role_id
    where uc.user_id = p_user_id
      and lower(ur.role_name) = 'admin'
      and uc.account_status = 'active'
  );
$$;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;
grant execute on function public.is_admin(uuid) to service_role;

-- =========================================================
-- ENABLE ROW LEVEL SECURITY
-- =========================================================

alter table public.user_credentials enable row level security;
alter table public.vendors enable row level security;
alter table public.drones enable row level security;
alter table public.drone_telemetry enable row level security;

-- =========================================================
-- USER CREDENTIALS
-- =========================================================

-- Only active admins can update user credentials.
drop policy if exists update_user_credentials
on public.user_credentials;

create policy update_user_credentials
on public.user_credentials
for update
to authenticated
using (
  public.is_admin(auth.uid())
)
with check (
  public.is_admin(auth.uid())
);

-- =========================================================
-- VENDORS
-- =========================================================

-- Vendor onboarding is handled by the authentication trigger.
-- Remove direct vendor insertion from the Flutter client.
drop policy if exists insert_vendors
on public.vendors;

-- Vendor owners can update their own store.
-- Active admins can update any vendor.
drop policy if exists update_vendors
on public.vendors;

create policy update_vendors
on public.vendors
for update
to authenticated
using (
  auth.uid() = user_id
  or public.is_admin(auth.uid())
)
with check (
  auth.uid() = user_id
  or public.is_admin(auth.uid())
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
-- 2. The student who owns the related order
-- 3. The vendor assigned to the related order
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
    left join public.vendors v
      on v.id = o.vendor_id
    where d.id = drone_telemetry.delivery_id
      and (
        o.user_id = auth.uid()
        or v.user_id = auth.uid()
      )
  )
);

commit;

notify pgrst, 'reload schema';