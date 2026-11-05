import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

if (!url || !anonKey) {
  throw new Error('VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY must be set to the Supabase project the AeroDrop app uses (see .env.example).')
}

/** The same project the app talks to (its SUPABASE_URL and SUPABASE_ANON_KEY dart-defines). */
export const supabase: SupabaseClient = createClient(url, anonKey)

/**
 * The app's Google Play listing. Download buttons only render when it is set,
 * so the site never links to a listing that does not exist.
 */
export const PLAY_STORE_URL = (import.meta.env.VITE_PLAY_STORE_URL as string | undefined)?.trim() || null

/** Admin addresses skip the login code, as in AuthConstants.isAdminEmail. */
const ADMIN_EMAILS = ['admin.portal@uclm.edu', 'admin@aerodrop.com', 'aerodrop.uclm+admin@gmail.com']
export const isAdminEmail = (email: string) => ADMIN_EMAILS.includes(email.trim().toLowerCase())
