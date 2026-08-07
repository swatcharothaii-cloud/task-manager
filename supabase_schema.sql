-- =========================================================
-- Task Manager — Supabase schema + Row Level Security
-- วิธีใช้: เปิด Supabase Dashboard -> SQL Editor -> New query
--          วางไฟล์นี้ทั้งหมด -> กด Run (รันครั้งเดียวพอ)
-- =========================================================

create extension if not exists "pgcrypto";

-- ---------- profiles: ข้อมูลผู้ใช้ (ชื่อที่แสดง, บทบาท) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'member' check (role in ('member','approver','admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_all_authenticated" on public.profiles;
create policy "profiles_select_all_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- สร้างแถว profile อัตโนมัติทุกครั้งที่มี user สมัครใหม่
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- tasks ----------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  assignee text,
  status text not null default 'todo' check (status in ('todo','doing','done')),
  project text,
  start_date date,
  due_date date,
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  remark text,
  approver_id uuid references auth.users(id) on delete set null,
  approval_status text not null default 'none' check (approval_status in ('none','pending','approved','rejected')),
  image_data text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ถ้าตาราง tasks มีอยู่แล้วจากการรันสคริปต์นี้รอบก่อน ให้เพิ่มคอลัมน์รูปภาพ (ไม่กระทบข้อมูลเดิม)
alter table public.tasks add column if not exists image_data text;

create index if not exists tasks_owner_idx on public.tasks(owner_id);
create index if not exists tasks_approver_idx on public.tasks(approver_id);

alter table public.tasks enable row level security;

drop policy if exists "tasks_select_own_or_approver" on public.tasks;
create policy "tasks_select_own_or_approver"
  on public.tasks for select
  to authenticated
  using (owner_id = auth.uid() or approver_id = auth.uid());

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own"
  on public.tasks for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "tasks_update_own_or_approver" on public.tasks;
create policy "tasks_update_own_or_approver"
  on public.tasks for update
  to authenticated
  using (owner_id = auth.uid() or approver_id = auth.uid())
  with check (owner_id = auth.uid() or approver_id = auth.uid());

drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own"
  on public.tasks for delete
  to authenticated
  using (owner_id = auth.uid());

-- auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tasks_set_updated_at on public.tasks;
create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute procedure public.set_updated_at();

-- ---------- task_updates: ประวัติการอัปเดตของแต่ละงาน ----------
create table if not exists public.task_updates (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  actor_id uuid references auth.users(id),
  text text not null,
  created_at timestamptz not null default now()
);

create index if not exists task_updates_task_idx on public.task_updates(task_id);

alter table public.task_updates enable row level security;

drop policy if exists "task_updates_select" on public.task_updates;
create policy "task_updates_select"
  on public.task_updates for select
  to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_updates.task_id
        and (t.owner_id = auth.uid() or t.approver_id = auth.uid())
    )
  );

drop policy if exists "task_updates_insert" on public.task_updates;
create policy "task_updates_insert"
  on public.task_updates for insert
  to authenticated
  with check (
    exists (
      select 1 from public.tasks t
      where t.id = task_updates.task_id
        and (t.owner_id = auth.uid() or t.approver_id = auth.uid())
    )
  );

-- =========================================================
-- เสร็จแล้ว! ถัดไปแนะนำให้ไปที่ Authentication -> Providers -> Email
-- แล้วปิด "Confirm email" ชั่วคราว เพื่อให้ user สมัครแล้ว login ได้ทันที
-- (ถ้าเปิดไว้ ผู้ใช้ต้องกดยืนยันในอีเมลก่อนถึงจะ login ได้)
-- =========================================================
