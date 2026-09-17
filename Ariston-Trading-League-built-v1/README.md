# Ariston Trading League

Next.js + Supabase foundation for a professional demo-trading tournament platform.

## Included
- Sign Up / Sign In screen with Continue with Google
- Profile-ready Supabase auth foundation
- Public tournament pages
- Tournament lifecycle data model
- Demo MT5 account assignment model
- Participant account/credential area
- Admin console modules
- Final-only leaderboard model
- Certificates, notifications and audit logs
- Dark, restrained Ariston visual system using the supplied logo
- No live participant account dashboard
- No live public leaderboard

## Setup
1. Copy `.env.example` to `.env.local`.
2. Add your Supabase project URL and publishable key.
3. Run `supabase/001_initial_schema.sql` in Supabase SQL Editor.
4. Enable Google in Supabase Auth and set the callback to `/auth/callback` on your deployed domain.
5. `npm install`
6. `npm run dev`

## Deployment
Use Vercel for Next.js. Keep server secrets and the MT5 bridge token out of the browser and Git.

## MT5 architecture
AWS Windows EC2 -> MT5 terminal -> Python collector -> authenticated server endpoint -> Supabase -> admin/results services.

Do not store plaintext MT5 passwords in PostgreSQL.

## Scope note
The real-money paid-entry, prize-wallet and UPI/bank/crypto withdrawal system is deliberately not implemented in this build.
