import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined

export const supabaseReady = Boolean(url && key && !url.includes('YOUR_PROJECT_ID') && !key.includes('YOUR_'))
export const supabase = createClient(
  url || 'https://example.supabase.co',
  key || 'placeholder-publishable-key'
)
