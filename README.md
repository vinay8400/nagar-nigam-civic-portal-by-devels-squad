# Nagar Nigam Civic Portal

React + Vite + TypeScript starter with a bilingual civic portal, interactive OpenStreetMap/Satellite map, complaint examples, email-based citizen login, complaint form, tracking UI, and responsive layout.

## Run locally
1. Open this folder in VS Code.
2. Run `npm install`
3. Review `.env.local` and confirm the Supabase project URL and publishable key are correct.
4. Run `npm run dev`

## Deploy to GitHub Pages
1. In GitHub, open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**. Do not select `main` branch or `/root` as the deployment source.
2. In **Settings → Secrets and variables → Actions → Variables**, add:
   - `VITE_SUPABASE_URL`: the existing Supabase project URL.
   - `VITE_SUPABASE_PUBLISHABLE_KEY`: the existing Supabase publishable (anon) key. It is intended for frontend use; never use a service-role key here.
   The workflow also accepts these names as Actions secrets if preferred.
3. Push to `main` or manually run **Actions → Deploy to GitHub Pages → Run workflow**. The workflow installs with `npm ci`, runs `npm run build`, and deploys only the generated `dist` artifact.
4. The production Vite base is `/nagar-nigam-civic-portal-by-devels-squad/`; local development continues to use `/`.
5. In Supabase Authentication → URL Configuration, allow `https://vinay8400.github.io/nagar-nigam-civic-portal-by-devels-squad/` as a redirect URL. Also allow `https://vinay8400.github.io/nagar-nigam-civic-portal-by-devels-squad/?auth=reset` for password recovery. Set the production Site URL to the project Pages URL. For Google OAuth, add `https://vinay8400.github.io` as an authorized JavaScript origin in Google Cloud; keep the Supabase callback URL in the OAuth client's authorized redirect URIs.

## Supabase setup still required
- In Supabase SQL Editor, review and run `supabase-setup.sql`.
- If Google/email Auth users exist but `public.profiles` is empty or missing rows, run `supabase-profile-trigger-migration.sql` in Supabase SQL Editor. It installs an idempotent `auth.users` trigger and backfills only missing profiles as `citizen`; existing profile rows, roles, and RLS policies are preserved.
- Verify profile creation with `SELECT u.id, u.email, p.role, p.full_name FROM auth.users AS u LEFT JOIN public.profiles AS p ON p.id = u.id ORDER BY u.created_at DESC LIMIT 20;`. Every Auth user should have one matching profile. The `role` for newly created/backfilled profiles should be `citizen`.
- To test the trigger, create a fresh test user with Google or email/password, then run the verification query again. The new user should appear in both `auth.users` and `public.profiles` with the same UUID and `citizen` role. Existing Google users are covered by the migration backfill; they do not need to sign in again to receive a profile.
- Enable email/password authentication in Supabase Auth settings.
- For Google login, create a Google OAuth Web client and enable Google under Supabase Authentication → Sign In / Providers. In Google Cloud, add `http://localhost:5173` and `https://vinay8400.github.io` as authorized JavaScript origins. Add the Supabase callback URI shown in the Google provider settings (usually `https://<project-ref>.supabase.co/auth/v1/callback`) as an authorized redirect URI.
- In Supabase Authentication → URL Configuration, set the Site URL to your GitHub Pages project URL and add `http://localhost:5173` plus `https://vinay8400.github.io/nagar-nigam-civic-portal-by-devels-squad/` to the Redirect URLs allow list. Vite is pinned to port 5173 for local development.
- For password recovery, also add the exact redirect URLs `http://localhost:5173/?auth=reset` and `https://vinay8400.github.io/nagar-nigam-civic-portal-by-devels-squad/?auth=reset` to Authentication → URL Configuration → Redirect URLs.
- Enter the Google Client ID and Client Secret only in the Supabase Google provider settings. Never put the Client Secret in `.env.local` or frontend code.
- Run the updated `supabase-setup.sql` in Supabase SQL Editor (also if you applied the earlier version). It creates the private `complaint-photos` bucket, citizen/admin complaint policies, and profiles from signup metadata.
- If complaint photo upload or display fails with a Storage RLS error, run `supabase-storage-rls-migration.sql` in Supabase SQL Editor. It replaces the app's named complaint-photo policies for the existing private bucket and supports `complaints/<user-uuid>/<complaint-uuid>/<filename>` paths. It does not make the bucket public.
- Grant admin access only from the Supabase SQL Editor after the account has signed up: `UPDATE public.profiles SET role = 'admin' WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@example.com');`. The Admin Panel is shown only to accounts with this database role.

## Important implementation notes
- `.env.local` contains the project's publishable key as supplied by the user. Publishable keys are intended for browser apps, but database access must be protected by RLS. Never add a `service_role` or secret key to frontend env files.
- Sign-up saves the user's name in Supabase Auth user metadata as `full_name`.
- Citizens can read their own complaints and photos. Admins can see all complaints, update statuses, and upload a resolution photo; the resolved status requires a photo upload.
- The current complaint form inserts into `public.complaints`; the SQL schema is the starting point. Review columns and policies against your real data model.
- Example map markers and complaint counts/photos are demo content until live database rows are loaded.
- The map uses OpenStreetMap tiles and Esri imagery for the Satellite toggle. GPS lookup uses OpenStreetMap Nominatim to turn coordinates into a readable address; both require internet access.
- Image links are illustrative sample photos loaded from Unsplash; use real complaint photos for actual reports.
