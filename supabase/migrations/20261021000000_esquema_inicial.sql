-- =============================================================================
-- Ortodoctor v3 — esquema completo do banco (Supabase / Postgres)
--
-- Como aplicar: Supabase > SQL Editor > colar este arquivo inteiro > Run.
-- Feito para um projeto Supabase NOVO (vazio).
--
-- Perfis de acesso (coluna profiles.role):
--   owner  = chefe (Staff Alfa): cria e gerencia várias empresas, equipe,
--            dias de atendimento, aprova pagamentos e tira relatórios.
--   staff  = funcionário (Staff Beta): trabalha em UMA empresa; gerencia
--            clientes, agenda, produtos e apenas o PRÓPRIO caixa.
--   client = cliente/paciente: vê só os próprios dados, agenda, cobranças,
--            produtos/promoções da empresa e faz perguntas.
--
-- Todas as tabelas têm RLS ligado. Ninguém escolhe o próprio perfil: o perfil
-- vem de app_metadata, que só as Edge Functions (chave de serviço) gravam.
-- =============================================================================

create extension if not exists pgcrypto;

-- Tipos -----------------------------------------------------------------------

create type public.user_role as enum ('owner', 'staff', 'client');
create type public.appointment_status as enum
  ('scheduled', 'confirmed', 'done', 'missed', 'canceled');
create type public.charge_status as enum ('open', 'paid', 'canceled');
create type public.cash_kind as enum ('in', 'out');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Perfis ------------------------------------------------------------------------

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.user_role not null default 'client',
  full_name   text not null default '',
  email       text,
  phone       text,
  company_id  uuid,               -- empresa do funcionário (staff)
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Empresas ------------------------------------------------------------------------

create table public.companies (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid not null references public.profiles (id) on delete restrict,
  name               text not null check (length(trim(name)) > 0),
  cnpj               text,
  phone              text,
  email              text,
  address            text,
  -- horário padrão da agenda (usado quando o dia não tem horário próprio)
  opening_time       time not null default '08:00',
  closing_time       time not null default '18:00',
  slot_minutes       int  not null default 30 check (slot_minutes between 5 and 240),
  max_per_slot       int  not null default 2  check (max_per_slot between 1 and 10),
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table public.profiles
  add constraint profiles_company_id_fkey
  foreign key (company_id) references public.companies (id) on delete set null;

create index on public.companies (owner_id);
create index on public.profiles (company_id);

-- Funções de acesso -------------------------------------------------------------
-- SECURITY DEFINER para poderem ler profiles/companies sem cair no próprio RLS.

create or replace function public.my_role()
returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid() and active
$$;

create or replace function public.is_owner()
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles where id = auth.uid() and active and role = 'owner'
  )
$$;

create or replace function public.owns_company(p_company uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from companies c
      join profiles p on p.id = c.owner_id
     where c.id = p_company
       and c.owner_id = auth.uid()
       and p.active and p.role = 'owner'
  )
$$;

-- Empresa do funcionário logado (null se não for funcionário ativo).
create or replace function public.staff_company()
returns uuid
language sql stable security definer set search_path = public as $$
  select company_id from profiles
   where id = auth.uid() and active and role = 'staff'
$$;

-- Chefe dono da empresa OU funcionário ativo dela.
create or replace function public.can_manage(p_company uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    p_company is not null
    and (public.owns_company(p_company) or public.staff_company() = p_company),
    false)
$$;


-- Perfil criado automaticamente para todo usuário do Auth -----------------------
-- O perfil e a empresa vêm de raw_app_meta_data (só a chave de serviço grava);
-- metadados enviados pelo app (raw_user_meta_data) servem apenas para o nome.

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role public.user_role;
begin
  v_role := coalesce(
    nullif(new.raw_app_meta_data ->> 'role', '')::public.user_role,
    'client'
  );
  insert into profiles (id, role, full_name, email, phone, company_id)
  values (
    new.id,
    v_role,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''),
             split_part(new.email, '@', 1)),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    case when v_role = 'staff'
         then nullif(new.raw_app_meta_data ->> 'company_id', '')::uuid end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- O Auth grava o app_metadata logo DEPOIS de criar o usuário (um UPDATE), por
-- isso o perfil e a empresa também são sincronizados na atualização.
create or replace function public.sync_user_role()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role public.user_role;
begin
  if new.raw_app_meta_data ->> 'role' is null then
    return new;
  end if;
  v_role := (new.raw_app_meta_data ->> 'role')::public.user_role;
  update profiles
     set role = v_role,
         company_id = case when v_role = 'staff'
                           then nullif(new.raw_app_meta_data ->> 'company_id', '')::uuid
                           else company_id end
   where id = new.id
     and (role is distinct from v_role
          or (v_role = 'staff' and company_id is null));
  return new;
end;
$$;

create trigger on_auth_user_app_metadata
  after update of raw_app_meta_data on auth.users
  for each row
  when (old.raw_app_meta_data is distinct from new.raw_app_meta_data)
  execute function public.sync_user_role();

-- Ninguém muda o próprio perfil de acesso pelo app. O chefe só mexe em
-- funcionários das próprias empresas (nome, telefone, ativo, empresa).
create or replace function public.profiles_guard()
returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if new.id <> old.id or new.role <> old.role or new.email is distinct from old.email then
    raise exception 'Alteração não permitida no perfil.' using errcode = '42501';
  end if;
  if new.id = auth.uid() then
    if new.active <> old.active or new.company_id is distinct from old.company_id then
      raise exception 'Alteração não permitida no próprio perfil.' using errcode = '42501';
    end if;
  else
    if old.role <> 'staff'
       or not public.owns_company(old.company_id)
       or (new.company_id is not null and not public.owns_company(new.company_id)) then
      raise exception 'Somente o chefe da empresa altera este funcionário.' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger companies_updated_at before update on public.companies
  for each row execute function public.set_updated_at();

-- Dias de atendimento (somente o chefe define — RN.3) ---------------------------

create table public.clinic_days (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies (id) on delete cascade,
  day         date not null,
  start_time  time not null default '08:00',
  end_time    time not null default '18:00',
  break_start time,
  break_end   time,
  notes       text,
  created_at  timestamptz not null default now(),
  unique (company_id, day),
  check (end_time > start_time),
  check ((break_start is null) = (break_end is null)),
  check (break_start is null or (break_end > break_start))
);

-- Clientes / pacientes ----------------------------------------------------------

create table public.patients (
  id                 uuid primary key default gen_random_uuid(),
  company_id         uuid not null references public.companies (id) on delete cascade,
  user_id            uuid references public.profiles (id) on delete set null,
  full_name          text not null check (length(trim(full_name)) > 0),
  cpf                text,
  birth_date         date,
  phone              text,
  email              text,
  guardian_name      text,
  guardian_cpf       text,
  address            text,
  notes              text,
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index on public.patients (company_id, full_name);
create index on public.patients (user_id);
create unique index patients_company_cpf_key
  on public.patients (company_id, cpf) where cpf is not null and cpf <> '';

-- Cliente com cadastro (paciente) nesta empresa.
create or replace function public.is_client_of(p_company uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from patients pt
      join profiles p on p.id = pt.user_id
     where pt.company_id = p_company
       and pt.user_id = auth.uid()
       and pt.active and p.active
  )
$$;

create trigger patients_updated_at before update on public.patients
  for each row execute function public.set_updated_at();

-- O vínculo com o login (user_id) só é feito pela Edge Function admin-users.
create or replace function public.patients_guard()
returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.user_id := null;
  elsif new.user_id is distinct from old.user_id then
    raise exception 'O acesso do cliente é criado pela tela "Criar acesso".' using errcode = '42501';
  elsif new.company_id <> old.company_id then
    raise exception 'Não é possível mudar o cliente de empresa.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger patients_guard before insert or update on public.patients
  for each row execute function public.patients_guard();

-- Agendamentos ----------------------------------------------------------------------

create table public.appointments (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references public.companies (id) on delete cascade,
  patient_id        uuid not null references public.patients (id) on delete cascade,
  professional_id   uuid references public.profiles (id) on delete set null,
  starts_at         timestamptz not null,
  duration_minutes  int not null default 30 check (duration_minutes between 5 and 480),
  status            public.appointment_status not null default 'scheduled',
  label             text,
  notes             text,
  created_by        uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on public.appointments (company_id, starts_at);
create index on public.appointments (patient_id, starts_at);

create trigger appointments_updated_at before update on public.appointments
  for each row execute function public.set_updated_at();

-- Paciente precisa ser da mesma empresa e cada horário aceita no máximo
-- companies.max_per_slot pacientes (RF.8: padrão 2).
create or replace function public.appointments_check()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_max int;
  v_count int;
begin
  if not exists (
    select 1 from patients where id = new.patient_id and company_id = new.company_id
  ) then
    raise exception 'O cliente não pertence a esta empresa.' using errcode = '23514';
  end if;

  if new.status = 'canceled' then
    return new;
  end if;

  select max_per_slot into v_max from companies where id = new.company_id;

  -- serializa agendamentos no mesmo horário da mesma empresa
  perform pg_advisory_xact_lock(hashtext(new.company_id::text || new.starts_at::text));

  select count(*) into v_count
    from appointments
   where company_id = new.company_id
     and starts_at = new.starts_at
     and status <> 'canceled'
     and id <> new.id;

  if v_count >= v_max then
    raise exception 'Este horário já tem % paciente(s), o limite da empresa.', v_count
      using errcode = '23514';
  end if;

  if exists (
    select 1 from appointments
     where patient_id = new.patient_id and starts_at = new.starts_at
       and status <> 'canceled' and id <> new.id
  ) then
    raise exception 'Este cliente já está agendado neste horário.' using errcode = '23505';
  end if;
  return new;
end;
$$;

create trigger appointments_check before insert or update on public.appointments
  for each row execute function public.appointments_check();

-- Cobranças (pendências do cliente) ---------------------------------------------

create table public.charges (
  id                  uuid primary key default gen_random_uuid(),
  company_id          uuid not null references public.companies (id) on delete cascade,
  patient_id          uuid not null references public.patients (id) on delete cascade,
  description         text not null,
  amount              numeric(12, 2) not null check (amount > 0),
  due_date            date not null,
  status              public.charge_status not null default 'open',
  group_id            uuid,                  -- parcelas do mesmo parcelamento
  installment_number  int,
  installment_total   int,
  -- etapa 1: quem recebeu (funcionário); etapa 2: aprovação do chefe (RN.8)
  paid_at             date,
  payment_method      text,
  received_by         uuid references public.profiles (id) on delete set null,
  approved_by         uuid references public.profiles (id) on delete set null,
  approved_at         timestamptz,
  created_by          uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index on public.charges (company_id, due_date);
create index on public.charges (patient_id, due_date);

create trigger charges_updated_at before update on public.charges
  for each row execute function public.set_updated_at();

-- Campos de pagamento/aprovação só mudam pelas funções pay_charge,
-- reverse_charge e approve_charge. Os gatilhos de
-- proteção rodam com o usuário do app (authenticated); as funções acima são
-- SECURITY DEFINER e por isso passam por eles.
create or replace function public.charges_guard()
returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.status = 'paid' or new.paid_at is not null or new.received_by is not null
       or new.approved_by is not null then
      raise exception 'Use "Receber pagamento" para dar baixa.' using errcode = '42501';
    end if;
    return new;
  end if;
  if new.status = 'paid' or old.status = 'paid'
     or new.paid_at is distinct from old.paid_at
     or new.received_by is distinct from old.received_by
     or new.approved_by is distinct from old.approved_by
     or new.approved_at is distinct from old.approved_at
     or new.company_id <> old.company_id
     or new.patient_id <> old.patient_id then
    raise exception 'Cobrança paga só pode ser alterada pelo estorno.' using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger charges_guard before insert or update on public.charges
  for each row execute function public.charges_guard();

-- Caixa ----------------------------------------------------------------------------
-- Cada lançamento pertence ao caixa de uma pessoa (staff_id).

create table public.cash_entries (
  id              uuid primary key default gen_random_uuid(),
  company_id      uuid not null references public.companies (id) on delete cascade,
  staff_id        uuid not null references public.profiles (id) on delete restrict,
  kind            public.cash_kind not null,
  amount          numeric(12, 2) not null check (amount > 0),
  description     text not null,
  payment_method  text,
  occurred_on     date not null default current_date,
  charge_id       uuid references public.charges (id) on delete set null,
  patient_id      uuid references public.patients (id) on delete set null,
  created_by      uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now()
);
create index on public.cash_entries (company_id, occurred_on);
create index on public.cash_entries (staff_id, occurred_on);
create unique index cash_entries_charge_key on public.cash_entries (charge_id)
  where charge_id is not null;

-- Lançamentos de recebimento de cobrança só pelas funções (tudo ou nada).
create or replace function public.cash_entries_guard()
returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  if (tg_op <> 'INSERT' and old.charge_id is not null)
     or (tg_op <> 'DELETE' and new.charge_id is not null) then
    raise exception 'Recebimento de cobrança: use o estorno na ficha do cliente.'
      using errcode = '42501';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger cash_entries_guard before insert or update or delete on public.cash_entries
  for each row execute function public.cash_entries_guard();

-- Produtos e promoções ------------------------------------------------------------

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies (id) on delete cascade,
  name         text not null check (length(trim(name)) > 0),
  description  text,
  category     text,
  price        numeric(12, 2) not null default 0 check (price >= 0),
  promo_price  numeric(12, 2) check (promo_price is null or promo_price >= 0),
  promo_until  date,
  is_promotion boolean not null default false,
  featured     boolean not null default false,  -- fixado no topo da vitrine
  image_url    text,
  image_path   text,
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index on public.products (company_id, active);

create trigger products_updated_at before update on public.products
  for each row execute function public.set_updated_at();

-- Dúvidas dos clientes (RF.16) ----------------------------------------------------

create table public.questions (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies (id) on delete cascade,
  patient_id   uuid not null references public.patients (id) on delete cascade,
  author_id    uuid default auth.uid() references public.profiles (id) on delete set null,
  message      text not null check (length(trim(message)) > 0),
  answer       text,
  answered_by  uuid references public.profiles (id) on delete set null,
  answered_at  timestamptz,
  created_at   timestamptz not null default now()
);
create index on public.questions (company_id, created_at desc);

create or replace function public.questions_guard()
returns trigger
language plpgsql set search_path = public as $$
begin
  -- Chave de serviço / exclusões em cascata (ex.: login apagado) passam direto.
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.answer := null; new.answered_by := null; new.answered_at := null;
    return new;
  end if;
  if new.message <> old.message or new.author_id is distinct from old.author_id
     or new.patient_id <> old.patient_id or new.company_id <> old.company_id then
    raise exception 'A pergunta não pode ser alterada.' using errcode = '42501';
  end if;
  if new.answer is distinct from old.answer then
    new.answered_by := auth.uid();
    new.answered_at := now();
  end if;
  return new;
end;
$$;

create trigger questions_guard before insert or update on public.questions
  for each row execute function public.questions_guard();

-- Pasta do paciente: boletos e outros documentos (arquivos no Storage) --------
-- O arquivo fica no bucket privado "patient-files" em
-- <company_id>/<patient_id>/<nome>. A clínica anexa; o cliente vê e baixa.

create table public.patient_files (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies (id) on delete cascade,
  patient_id    uuid not null references public.patients (id) on delete cascade,
  charge_id     uuid references public.charges (id) on delete set null,
  kind          text not null default 'boleto' check (kind in ('boleto', 'documento')),
  title         text not null check (length(trim(title)) > 0),
  due_date      date,
  file_path     text not null unique,
  file_name     text not null,
  content_type  text,
  size_bytes    bigint,
  uploaded_by   uuid default auth.uid() references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now()
);
create index on public.patient_files (patient_id, created_at desc);
create index on public.patient_files (charge_id);

-- O arquivo precisa estar na pasta do próprio paciente e a cobrança ligada
-- precisa ser dele.
create or replace function public.patient_files_check()
returns trigger
language plpgsql set search_path = public as $$
begin
  if not exists (
    select 1 from patients where id = new.patient_id and company_id = new.company_id
  ) then
    raise exception 'O cliente não pertence a esta empresa.' using errcode = '23514';
  end if;
  if new.file_path not like new.company_id::text || '/' || new.patient_id::text || '/%' then
    raise exception 'Arquivo fora da pasta do cliente.' using errcode = '23514';
  end if;
  if new.charge_id is not null and not exists (
    select 1 from charges where id = new.charge_id and patient_id = new.patient_id
  ) then
    raise exception 'A cobrança não é deste cliente.' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger patient_files_check before insert or update on public.patient_files
  for each row execute function public.patient_files_check();

-- Acesso a um arquivo do Storage pelo caminho <company_id>/<patient_id>/...
-- p_write: true = enviar/apagar (só a equipe da empresa).
create or replace function public.patient_folder_access(p_name text, p_write boolean)
returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  parts text[] := string_to_array(p_name, '/');
  v_company uuid;
  v_patient uuid;
begin
  if array_length(parts, 1) < 3
     or parts[1] !~ '^[0-9a-f-]{36}$' or parts[2] !~ '^[0-9a-f-]{36}$' then
    return false;
  end if;
  v_company := parts[1]::uuid;
  v_patient := parts[2]::uuid;
  if public.can_manage(v_company) then
    return exists (select 1 from patients where id = v_patient and company_id = v_company);
  end if;
  if p_write then
    return false;
  end if;
  return exists (
    select 1 from patients
     where id = v_patient and company_id = v_company and user_id = auth.uid() and active
  );
end;
$$;

-- =============================================================================
-- RLS
-- =============================================================================

alter table public.profiles      enable row level security;
alter table public.companies     enable row level security;
alter table public.clinic_days   enable row level security;
alter table public.patients      enable row level security;
alter table public.appointments  enable row level security;
alter table public.charges       enable row level security;
alter table public.cash_entries  enable row level security;
alter table public.products      enable row level security;
alter table public.questions     enable row level security;
alter table public.patient_files enable row level security;

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or (company_id is not null and public.can_manage(company_id))
    or exists (select 1 from companies c where c.owner_id = profiles.id
                 and public.can_manage(c.id))
  );
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or (role = 'staff' and public.owns_company(company_id)))
  with check (id = auth.uid() or (role = 'staff' and public.owns_company(company_id)));

-- companies
-- owner_id = auth.uid() direto na linha: no INSERT ... RETURNING a empresa
-- recém-criada ainda não aparece para as funções de consulta.
create policy companies_select on public.companies for select to authenticated
  using (
    (owner_id = auth.uid() and public.is_owner())
    or public.staff_company() = id
    or public.is_client_of(id)
  );
create policy companies_insert on public.companies for insert to authenticated
  with check (owner_id = auth.uid() and public.is_owner());
create policy companies_update on public.companies for update to authenticated
  using (public.owns_company(id)) with check (owner_id = auth.uid());
create policy companies_delete on public.companies for delete to authenticated
  using (public.owns_company(id));

-- clinic_days
create policy clinic_days_select on public.clinic_days for select to authenticated
  using (public.can_manage(company_id) or public.is_client_of(company_id));
create policy clinic_days_write on public.clinic_days for all to authenticated
  using (public.owns_company(company_id)) with check (public.owns_company(company_id));

-- patients
create policy patients_select on public.patients for select to authenticated
  using (public.can_manage(company_id) or user_id = auth.uid());
create policy patients_insert on public.patients for insert to authenticated
  with check (public.can_manage(company_id));
create policy patients_update on public.patients for update to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));
create policy patients_delete on public.patients for delete to authenticated
  using (public.can_manage(company_id));

-- appointments (RN.11: cliente só consulta)
create policy appointments_select on public.appointments for select to authenticated
  using (
    public.can_manage(company_id)
    or exists (select 1 from patients p where p.id = patient_id and p.user_id = auth.uid())
  );
create policy appointments_write on public.appointments for all to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));

-- charges (RN.10: cliente não dá baixa)
create policy charges_select on public.charges for select to authenticated
  using (
    public.can_manage(company_id)
    or exists (select 1 from patients p where p.id = patient_id and p.user_id = auth.uid())
  );
create policy charges_write on public.charges for all to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));

-- cash_entries: funcionário só o próprio caixa (RN.5); chefe vê todos (RN.2)
create policy cash_select on public.cash_entries for select to authenticated
  using (
    public.owns_company(company_id)
    or (staff_id = auth.uid() and public.staff_company() = company_id)
  );
create policy cash_insert on public.cash_entries for insert to authenticated
  with check (
    staff_id = auth.uid()
    and (public.owns_company(company_id) or public.staff_company() = company_id)
  );
create policy cash_update on public.cash_entries for update to authenticated
  using (
    public.owns_company(company_id)
    or (staff_id = auth.uid() and public.staff_company() = company_id)
  )
  with check (
    public.owns_company(company_id)
    or (staff_id = auth.uid() and public.staff_company() = company_id)
  );
create policy cash_delete on public.cash_entries for delete to authenticated
  using (
    public.owns_company(company_id)
    or (staff_id = auth.uid() and public.staff_company() = company_id)
  );

-- products: cliente vê os ativos da empresa dele
create policy products_select on public.products for select to authenticated
  using (public.can_manage(company_id) or (active and public.is_client_of(company_id)));
create policy products_write on public.products for all to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));

-- questions
create policy questions_select on public.questions for select to authenticated
  using (public.can_manage(company_id) or author_id = auth.uid());
create policy questions_insert on public.questions for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from patients p
       where p.id = patient_id and p.company_id = questions.company_id
         and p.user_id = auth.uid()
    )
  );
create policy questions_answer on public.questions for update to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));
create policy questions_delete on public.questions for delete to authenticated
  using (public.can_manage(company_id) or (author_id = auth.uid() and answer is null));

-- patient_files: equipe gerencia; cliente vê os da própria ficha
create policy patient_files_select on public.patient_files for select to authenticated
  using (
    public.can_manage(company_id)
    or exists (select 1 from patients p where p.id = patient_id and p.user_id = auth.uid() and p.active)
  );
create policy patient_files_write on public.patient_files for all to authenticated
  using (public.can_manage(company_id)) with check (public.can_manage(company_id));

-- =============================================================================
-- Funções de pagamento (tudo ou nada)
-- =============================================================================

-- Etapa 1: recebe o pagamento e lança a entrada no caixa de quem recebeu.
-- Se quem recebe é o chefe, a aprovação já fica feita.
create or replace function public.pay_charge(
  p_charge_id uuid,
  p_method text,
  p_paid_on date default current_date
)
returns public.charges
language plpgsql security definer set search_path = public as $$
declare
  c charges;
  v_owner boolean;
begin
  select * into c from charges where id = p_charge_id for update;
  if not found or not public.can_manage(c.company_id) then
    raise exception 'Cobrança não encontrada.' using errcode = '42501';
  end if;
  if c.status <> 'open' then
    raise exception 'Esta cobrança não está em aberto.' using errcode = '23514';
  end if;

  v_owner := public.owns_company(c.company_id);

  update charges set
    status = 'paid',
    paid_at = coalesce(p_paid_on, current_date),
    payment_method = nullif(trim(p_method), ''),
    received_by = auth.uid(),
    approved_by = case when v_owner then auth.uid() end,
    approved_at = case when v_owner then now() end
  where id = c.id
  returning * into c;

  insert into cash_entries
    (company_id, staff_id, kind, amount, description, payment_method,
     occurred_on, charge_id, patient_id)
  values
    (c.company_id, auth.uid(), 'in', c.amount, c.description, c.payment_method,
     c.paid_at, c.id, c.patient_id);

  return c;
end;
$$;

-- Estorno: volta a cobrança para "em aberto" e remove a entrada do caixa.
-- Funcionário só estorna o que ele mesmo recebeu e o chefe ainda não aprovou.
create or replace function public.reverse_charge(p_charge_id uuid)
returns public.charges
language plpgsql security definer set search_path = public as $$
declare
  c charges;
begin
  select * into c from charges where id = p_charge_id for update;
  if not found or not public.can_manage(c.company_id) then
    raise exception 'Cobrança não encontrada.' using errcode = '42501';
  end if;
  if c.status <> 'paid' then
    raise exception 'Esta cobrança não está paga.' using errcode = '23514';
  end if;
  if not public.owns_company(c.company_id)
     and (c.received_by is distinct from auth.uid() or c.approved_by is not null) then
    raise exception 'Somente o chefe pode estornar este pagamento.' using errcode = '42501';
  end if;

  delete from cash_entries where charge_id = c.id;
  update charges set
    status = 'open', paid_at = null, payment_method = null,
    received_by = null, approved_by = null, approved_at = null
  where id = c.id
  returning * into c;
  return c;
end;
$$;

-- Etapa 2: aprovação financeira do chefe.
create or replace function public.approve_charge(p_charge_id uuid)
returns public.charges
language plpgsql security definer set search_path = public as $$
declare
  c charges;
begin
  select * into c from charges where id = p_charge_id for update;
  if not found or not public.owns_company(c.company_id) then
    raise exception 'Somente o chefe aprova pagamentos.' using errcode = '42501';
  end if;
  if c.status <> 'paid' then
    raise exception 'Só pagamentos recebidos podem ser aprovados.' using errcode = '23514';
  end if;
  if c.approved_by is not null then
    return c;
  end if;
  update charges set approved_by = auth.uid(), approved_at = now()
   where id = c.id returning * into c;
  return c;
end;
$$;

-- Parcelamento: cria N parcelas de uma vez (centavos que sobram vão na última).
create or replace function public.create_installments(
  p_patient_id uuid,
  p_description text,
  p_total numeric,
  p_count int,
  p_first_due date
)
returns setof public.charges
language plpgsql security invoker set search_path = public as $$
declare
  v_company uuid;
  v_group uuid := gen_random_uuid();
  v_part numeric(12, 2);
  i int;
begin
  if p_count < 1 or p_count > 120 then
    raise exception 'Quantidade de parcelas inválida.' using errcode = '22023';
  end if;
  if p_total is null or p_total <= 0 then
    raise exception 'Valor inválido.' using errcode = '22023';
  end if;
  select company_id into v_company from patients where id = p_patient_id;
  if v_company is null then
    raise exception 'Cliente não encontrado.' using errcode = '42501';
  end if;
  v_part := trunc(p_total / p_count, 2);
  for i in 1..p_count loop
    return query
    insert into charges
      (company_id, patient_id, description, amount, due_date,
       group_id, installment_number, installment_total)
    values
      (v_company, p_patient_id,
       case when p_count > 1 then p_description || ' (' || i || '/' || p_count || ')'
            else p_description end,
       case when i = p_count then p_total - v_part * (p_count - 1) else v_part end,
       (p_first_due + make_interval(months => i - 1))::date,
       v_group, i, p_count)
    returning *;
  end loop;
end;
$$;

-- Perfil: o próprio usuário altera nome e telefone.
create or replace function public.update_my_profile(p_full_name text, p_phone text)
returns public.profiles
language sql security invoker set search_path = public as $$
  update profiles
     set full_name = coalesce(nullif(trim(p_full_name), ''), full_name),
         phone = nullif(trim(p_phone), '')
   where id = auth.uid()
  returning *;
$$;

-- =============================================================================
-- Relatórios (chefe). p_company null = todas as empresas do chefe.
-- =============================================================================

create or replace function public.report_companies(p_company uuid)
returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from companies
   where owner_id = auth.uid() and public.is_owner()
     and (p_company is null or id = p_company)
$$;

-- Faturamento por mês (entradas, saídas e saldo do caixa).
create or replace function public.report_revenue_by_month(
  p_company uuid, p_from date, p_to date)
returns table (company_id uuid, company_name text, month date,
               total_in numeric, total_out numeric, balance numeric)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, date_trunc('month', e.occurred_on)::date,
         coalesce(sum(e.amount) filter (where e.kind = 'in'), 0),
         coalesce(sum(e.amount) filter (where e.kind = 'out'), 0),
         coalesce(sum(case when e.kind = 'in' then e.amount else -e.amount end), 0)
    from cash_entries e
    join companies c on c.id = e.company_id
   where e.company_id in (select public.report_companies(p_company))
     and e.occurred_on between p_from and p_to
   group by 1, 2, 3
   order by 3, 2
$$;

-- Inadimplência: cobranças em aberto vencidas até p_ref.
create or replace function public.report_overdue(p_company uuid, p_ref date)
returns table (company_name text, patient_name text, patient_phone text,
               description text, due_date date, amount numeric, days_late int)
language sql stable security definer set search_path = public as $$
  select c.name, p.full_name, p.phone, ch.description, ch.due_date, ch.amount,
         (p_ref - ch.due_date)::int
    from charges ch
    join patients p on p.id = ch.patient_id
    join companies c on c.id = ch.company_id
   where ch.company_id in (select public.report_companies(p_company))
     and ch.status = 'open' and ch.due_date < p_ref
   order by ch.due_date, p.full_name
$$;

-- Atendimentos por período, agrupados por empresa e situação.
create or replace function public.report_appointments(
  p_company uuid, p_from date, p_to date)
returns table (company_name text, status public.appointment_status, total bigint)
language sql stable security definer set search_path = public as $$
  select c.name, a.status, count(*)
    from appointments a
    join companies c on c.id = a.company_id
   where a.company_id in (select public.report_companies(p_company))
     and (a.starts_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
   group by 1, 2
   order by 1, 2
$$;

-- Caixa por funcionário, com recebimentos aprovados em duas etapas (RN.8).
create or replace function public.report_cash_by_staff(
  p_company uuid, p_from date, p_to date)
returns table (company_name text, staff_id uuid, staff_name text,
               total_in numeric, total_out numeric, balance numeric,
               received_count bigint, approved_two_step bigint, pending_approval bigint)
language sql stable security definer set search_path = public as $$
  select c.name, pr.id, pr.full_name,
         coalesce(sum(e.amount) filter (where e.kind = 'in'), 0),
         coalesce(sum(e.amount) filter (where e.kind = 'out'), 0),
         coalesce(sum(case when e.kind = 'in' then e.amount else -e.amount end), 0),
         count(ch.id),
         count(ch.id) filter (where ch.approved_by is not null
                                and ch.approved_by <> ch.received_by),
         count(ch.id) filter (where ch.approved_by is null)
    from cash_entries e
    join companies c on c.id = e.company_id
    join profiles pr on pr.id = e.staff_id
    left join charges ch on ch.id = e.charge_id
   where e.company_id in (select public.report_companies(p_company))
     and e.occurred_on between p_from and p_to
   group by 1, 2, 3
   order by 1, 3
$$;

-- =============================================================================
-- Storage: imagens de produtos (bucket público, envio só por quem gerencia)
-- Caminho do arquivo: <company_id>/<nome>.jpg
-- =============================================================================

insert into storage.buckets (id, name, public)
values ('products', 'products', true)
on conflict (id) do nothing;

create policy products_images_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'products'
    and public.can_manage(nullif((storage.foldername(name))[1], '')::uuid)
  );
create policy products_images_update on storage.objects for update to authenticated
  using (
    bucket_id = 'products'
    and public.can_manage(nullif((storage.foldername(name))[1], '')::uuid)
  );
create policy products_images_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'products'
    and public.can_manage(nullif((storage.foldername(name))[1], '')::uuid)
  );

-- Pasta do paciente: bucket PRIVADO (o app gera links temporários para baixar)
insert into storage.buckets (id, name, public)
values ('patient-files', 'patient-files', false)
on conflict (id) do nothing;

create policy patient_files_read on storage.objects for select to authenticated
  using (bucket_id = 'patient-files' and public.patient_folder_access(name, false));
create policy patient_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'patient-files' and public.patient_folder_access(name, true));
create policy patient_files_update on storage.objects for update to authenticated
  using (bucket_id = 'patient-files' and public.patient_folder_access(name, true));
create policy patient_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'patient-files' and public.patient_folder_access(name, true));
