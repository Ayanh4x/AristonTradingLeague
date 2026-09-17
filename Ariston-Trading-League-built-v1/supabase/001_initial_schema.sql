create extension if not exists pgcrypto;
create type public.user_role as enum ('SUPER_ADMIN','ADMIN','OPERATIONS','SUPPORT','MODERATOR','USER');
create type public.tournament_status as enum ('DRAFT','SCHEDULED','REGISTRATION_OPEN','REGISTRATION_CLOSED','LIVE','PAUSED','ENDED','RESULTS_VERIFICATION','COMPLETED','ARCHIVED');
create type public.account_status as enum ('PENDING','PREPARING','READY','ACTIVE','SUSPENDED','COMPLETED','ARCHIVED');

create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,email text unique,first_name text,last_name text,legal_full_name text,phone text,country text,username text unique,avatar_url text,role public.user_role not null default 'USER',profile_complete boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.tournaments(id uuid primary key default gen_random_uuid(),slug text unique not null,name text not null,description text,status public.tournament_status not null default 'DRAFT',starting_balance numeric(18,2) not null default 5000,leverage text default '1:100',max_participants integer not null default 100,starts_at timestamptz,ends_at timestamptz,created_by uuid references public.profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.tournament_participants(id uuid primary key default gen_random_uuid(),tournament_id uuid not null references public.tournaments(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,joined_at timestamptz not null default now(),status text not null default 'REGISTERED',final_rank integer,final_return_pct numeric(12,4),max_drawdown_pct numeric(12,4),completed_trades integer,final_score_achieved_at timestamptz,unique(tournament_id,user_id));
create table public.mt5_accounts(id uuid primary key default gen_random_uuid(),tournament_id uuid not null references public.tournaments(id) on delete cascade,participant_id uuid not null unique references public.tournament_participants(id) on delete cascade,login bigint,server text,status public.account_status not null default 'PENDING',starting_balance numeric(18,2) not null default 5000,assigned_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.mt5_credential_refs(id uuid primary key default gen_random_uuid(),mt5_account_id uuid not null unique references public.mt5_accounts(id) on delete cascade,login_secret_ref text,investor_secret_ref text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table public.account_snapshots(id uuid primary key default gen_random_uuid(),mt5_account_id uuid not null references public.mt5_accounts(id) on delete cascade,balance numeric(18,2),equity numeric(18,2),floating_pnl numeric(18,2),captured_at timestamptz not null default now());
create table public.trades(id uuid primary key default gen_random_uuid(),mt5_account_id uuid not null references public.mt5_accounts(id) on delete cascade,ticket bigint,symbol text,side text,volume numeric(18,4),open_price numeric(18,8),close_price numeric(18,8),profit numeric(18,2),opened_at timestamptz,closed_at timestamptz,source text default 'MT5');
create table public.final_results(id uuid primary key default gen_random_uuid(),tournament_id uuid not null references public.tournaments(id) on delete cascade,participant_id uuid not null references public.tournament_participants(id) on delete cascade,rank integer not null,return_pct numeric(12,4) not null,max_drawdown_pct numeric(12,4),completed_trades integer,final_score_achieved_at timestamptz,published_at timestamptz,unique(tournament_id,participant_id),unique(tournament_id,rank));
create table public.certificates(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,tournament_id uuid references public.tournaments(id) on delete set null,title text not null,file_path text not null,issued_at timestamptz not null default now(),issued_by uuid references public.profiles(id));
create table public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid references public.profiles(id) on delete cascade,title text not null,body text not null,type text not null,read_at timestamptz,created_at timestamptz not null default now());
create table public.audit_logs(id uuid primary key default gen_random_uuid(),actor_user_id uuid references public.profiles(id) on delete set null,action text not null,target_type text,target_id text,previous_value jsonb,new_value jsonb,created_at timestamptz not null default now());

create index on public.tournament_participants(tournament_id);
create index on public.tournament_participants(user_id);
create index on public.account_snapshots(mt5_account_id,captured_at desc);
create index on public.trades(mt5_account_id,closed_at desc);
create index on public.final_results(tournament_id,rank);

alter table public.profiles enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_participants enable row level security;
alter table public.mt5_accounts enable row level security;
alter table public.mt5_credential_refs enable row level security;
alter table public.account_snapshots enable row level security;
alter table public.trades enable row level security;
alter table public.final_results enable row level security;
alter table public.certificates enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

create policy "public tournaments" on public.tournaments for select using (status in ('SCHEDULED','REGISTRATION_OPEN','REGISTRATION_CLOSED','LIVE','PAUSED','ENDED','COMPLETED'));
create policy "own profile read" on public.profiles for select using (auth.uid()=id);
create policy "own profile update" on public.profiles for update using (auth.uid()=id);
create policy "own participation read" on public.tournament_participants for select using (auth.uid()=user_id);
create policy "own mt5 account read" on public.mt5_accounts for select using (exists(select 1 from public.tournament_participants p where p.id=mt5_accounts.participant_id and p.user_id=auth.uid()));

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,email,avatar_url) values(new.id,new.email,new.raw_user_meta_data->>'avatar_url') on conflict(id) do nothing; return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Credential references intentionally contain no plaintext passwords.
-- Admin mutations and secret retrieval must be server-side and protected by RBAC.
-- Real-money payment, prize wallet and withdrawal tables are intentionally not included.
