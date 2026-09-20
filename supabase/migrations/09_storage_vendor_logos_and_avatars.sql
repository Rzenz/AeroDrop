-- ============================================================
-- 09_STORAGE_VENDOR_LOGOS_AND_AVATARS.SQL
-- Migration: Vendor Logos & User Avatars Storage Buckets & Policies
-- Allows authenticated users (including pending vendor applicants)
-- to upload, update, and manage their own logo and avatar assets.
-- ============================================================

-- 1. STORAGE BUCKETS: vendor-logos & avatars
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('vendor-logos', 'vendor-logos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. POLICIES: vendor-logos
-- ============================================================

DROP POLICY IF EXISTS "Public Access to Vendor Logos" ON storage.objects;
CREATE POLICY "Public Access to Vendor Logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'vendor-logos');

DROP POLICY IF EXISTS "Owner Upload Vendor Logos" ON storage.objects;
CREATE POLICY "Owner Upload Vendor Logos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Update Vendor Logos" ON storage.objects;
CREATE POLICY "Owner Update Vendor Logos"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Delete Vendor Logos" ON storage.objects;
CREATE POLICY "Owner Delete Vendor Logos"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'vendor-logos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. POLICIES: avatars
-- ============================================================

DROP POLICY IF EXISTS "Public Access to Avatars" ON storage.objects;
CREATE POLICY "Public Access to Avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Owner Upload Avatars" ON storage.objects;
CREATE POLICY "Owner Upload Avatars"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Update Avatars" ON storage.objects;
CREATE POLICY "Owner Update Avatars"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Owner Delete Avatars" ON storage.objects;
CREATE POLICY "Owner Delete Avatars"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
