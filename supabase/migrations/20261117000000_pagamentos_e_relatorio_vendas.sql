-- =============================================================================
-- Ortodoctor v3 — Recebimentos em várias formas, pagamento parcial e
-- relatório mensal de vendas (.xlsx)
--
-- COMO USAR: Supabase > SQL Editor > New query > colar este arquivo inteiro
-- > Run. Pode rodar mais de uma vez sem problema. Não apaga nenhum dado.
--
-- O que muda:
--  * Nova tabela charge_payments: cada pagamento recebido de uma cobrança
--    (forma, valor, parcelas do cartão, juros, data e quem recebeu).
--    Uma cobrança pode ter vários pagamentos (várias formas e/ou parcial).
--  * Cada pagamento gera a sua própria entrada no caixa de quem recebeu.
--  * Nova função receive_payment (usada pelo botão "Receber pagamento").
--  * pay_charge e reverse_charge passam a usar a tabela nova.
--  * Novas funções do relatório mensal de vendas: chefe e funcionários.
-- =============================================================================

begin;

-- Pagamentos recebidos --------------------------------------------------------

create table if not exists public.charge_payments (
  id            uuid primary key default gen_random_uuid(),
  charge_id     uuid not null references public.charges (id) on delete cascade,
  company_id    uuid not null references public.companies (id) on delete cascade,
  patient_id    uuid not null references public.patients (id) on delete cascade,
  method        text not null check (length(trim(method)) > 0),
  installments  int not null default 1 check (installments between 1 and 24),
  amount        numeric(12, 2) not null check (amount > 0),
  interest      numeric(12, 2) not null default 0 check (interest >= 0),
  paid_on       date not null default current_date,
  received_by   uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now()
);
create index if not exists charge_payments_charge_idx on public.charge_payments (charge_id);
create index if not exists charge_payments_company_idx on public.charge_payments (company_id, paid_on);

alter table public.charge_payments enable row level security;

-- Leitura: equipe da empresa e o próprio paciente. Gravação só pelas funções
-- abaixo (não há policy de escrita).
drop policy if exists charge_payments_select on public.charge_payments;
create policy charge_payments_select on public.charge_payments for select to authenticated
  using (
    public.can_manage(company_id)
    or exists (select 1 from patients p where p.id = patient_id and p.user_id = auth.uid())
  );

-- Entrada do caixa ligada ao pagamento.
alter table public.cash_entries
  add column if not exists payment_id uuid references public.charge_payments (id) on delete set null;
create index if not exists cash_entries_payment_idx on public.cash_entries (payment_id);

-- Antes só podia existir UMA entrada no caixa por cobrança. Agora cada
-- pagamento (Pix + cartão, parcial etc.) tem a sua.
drop index if exists public.cash_entries_charge_key;

-- Cobranças antigas já pagas: registra o pagamento delas na tabela nova,
-- para aparecerem no relatório com a forma de pagamento.
insert into public.charge_payments
  (charge_id, company_id, patient_id, method, amount, paid_on, received_by, created_at)
select ch.id, ch.company_id, ch.patient_id, coalesce(nullif(trim(ch.payment_method), ''), 'Não informada'),
       ch.amount, coalesce(ch.paid_at, current_date), ch.received_by, coalesce(ch.approved_at, ch.updated_at)
  from public.charges ch
 where ch.status = 'paid'
   and not exists (select 1 from public.charge_payments cp where cp.charge_id = ch.id);

update public.cash_entries e
   set payment_id = cp.id
  from public.charge_payments cp
 where e.charge_id = cp.charge_id
   and e.payment_id is null
   and e.kind = 'in';

-- Cobrança com pagamento recebido (mesmo parcial) não pode ser excluída,
-- cancelada nem ficar com valor menor do que o já pago. Para isso, estorne.
create or replace function public.charges_payments_guard()
returns trigger
language plpgsql set search_path = public as $$
declare
  v_paid numeric;
begin
  if current_user not in ('authenticated', 'anon') then
    return coalesce(new, old);
  end if;
  select coalesce(sum(amount), 0) into v_paid from charge_payments where charge_id = old.id;
  if v_paid = 0 then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' then
    raise exception 'Esta cobrança já tem pagamento recebido. Estorne antes de excluir.' using errcode = '42501';
  end if;
  if new.status = 'canceled' then
    raise exception 'Esta cobrança já tem pagamento recebido. Estorne antes de cancelar.' using errcode = '42501';
  end if;
  if new.amount < v_paid then
    raise exception 'O valor não pode ser menor do que o já pago (%).', v_paid using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists charges_payments_guard on public.charges;
create trigger charges_payments_guard before update or delete on public.charges
  for each row execute function public.charges_payments_guard();

-- Receber pagamento -----------------------------------------------------------
-- p_parts = lista de formas, ex.:
--   [{"method":"Pix","amount":100},
--    {"method":"Cartão de crédito","amount":150,"installments":3}]
-- p_interest = juros/multa cobrados neste recebimento (entra no caixa junto
-- com a primeira forma, mas não abate da cobrança).
-- A soma pode ser menor que o que falta (pagamento parcial): a cobrança
-- continua em aberto com o restante. Quando quita, fica "paga".
create or replace function public.receive_payment(
  p_charge_id uuid,
  p_parts jsonb,
  p_paid_on date default current_date,
  p_interest numeric default 0
)
returns public.charges
language plpgsql security definer set search_path = public as $$
declare
  c charges;
  v_owner boolean;
  v_paid numeric;
  v_remaining numeric;
  v_total numeric := 0;
  v_part jsonb;
  v_method text;
  v_amount numeric;
  v_inst int;
  v_interest numeric := greatest(coalesce(p_interest, 0), 0);
  v_payment uuid;
  v_first boolean := true;
  v_date date := coalesce(p_paid_on, current_date);
  v_methods text;
begin
  select * into c from charges where id = p_charge_id for update;
  if not found or not public.can_manage(c.company_id) then
    raise exception 'Cobrança não encontrada.' using errcode = '42501';
  end if;
  if c.status <> 'open' then
    raise exception 'Esta cobrança não está em aberto.' using errcode = '23514';
  end if;
  if p_parts is null or jsonb_typeof(p_parts) <> 'array' or jsonb_array_length(p_parts) = 0 then
    raise exception 'Informe ao menos uma forma de pagamento.' using errcode = '22023';
  end if;
  if v_date > current_date + 1 then
    raise exception 'A data do pagamento não pode ser no futuro.' using errcode = '22023';
  end if;

  select coalesce(sum(amount), 0) into v_paid from charge_payments where charge_id = c.id;
  v_remaining := c.amount - v_paid;

  for v_part in select * from jsonb_array_elements(p_parts) loop
    v_amount := round(coalesce((v_part ->> 'amount')::numeric, 0), 2);
    if v_amount <= 0 then
      raise exception 'Valor de pagamento inválido.' using errcode = '22023';
    end if;
    v_total := v_total + v_amount;
  end loop;
  if v_total > v_remaining + 0.001 then
    raise exception 'A soma dos pagamentos (%) é maior do que o valor em aberto (%).',
      v_total, v_remaining using errcode = '23514';
  end if;

  v_owner := public.owns_company(c.company_id);

  for v_part in select * from jsonb_array_elements(p_parts) loop
    v_method := nullif(trim(v_part ->> 'method'), '');
    if v_method is null then
      raise exception 'Escolha a forma de pagamento.' using errcode = '22023';
    end if;
    v_amount := round((v_part ->> 'amount')::numeric, 2);
    v_inst := least(greatest(coalesce((v_part ->> 'installments')::int, 1), 1), 24);

    insert into charge_payments
      (charge_id, company_id, patient_id, method, installments, amount, interest, paid_on, received_by)
    values
      (c.id, c.company_id, c.patient_id, v_method, v_inst, v_amount,
       case when v_first then v_interest else 0 end, v_date, auth.uid())
    returning id into v_payment;

    insert into cash_entries
      (company_id, staff_id, kind, amount, description, payment_method,
       occurred_on, charge_id, patient_id, payment_id)
    values
      (c.company_id, auth.uid(), 'in',
       v_amount + case when v_first then v_interest else 0 end,
       c.description || case when v_total + v_paid < c.amount - 0.001 then ' (parcial)' else '' end,
       v_method, v_date, c.id, c.patient_id, v_payment);

    v_first := false;
  end loop;

  if v_paid + v_total >= c.amount - 0.001 then
    select string_agg(m, ' + ' order by m) into v_methods
      from (select distinct method || case when installments > 1 then ' ' || installments || 'x' else '' end as m
              from charge_payments where charge_id = c.id) x;
    update charges set
      status = 'paid',
      paid_at = v_date,
      payment_method = v_methods,
      received_by = auth.uid(),
      approved_by = case when v_owner then auth.uid() end,
      approved_at = case when v_owner then now() end
    where id = c.id
    returning * into c;
  end if;

  return c;
end;
$$;

-- Compatibilidade: a função antiga recebe o valor que falta numa forma só.
create or replace function public.pay_charge(
  p_charge_id uuid,
  p_method text,
  p_paid_on date default current_date
)
returns public.charges
language plpgsql security definer set search_path = public as $$
declare
  v_remaining numeric;
begin
  select ch.amount - coalesce((select sum(amount) from charge_payments where charge_id = ch.id), 0)
    into v_remaining
    from charges ch where ch.id = p_charge_id;
  return public.receive_payment(
    p_charge_id,
    jsonb_build_array(jsonb_build_object('method', p_method, 'amount', v_remaining)),
    p_paid_on, 0);
end;
$$;

-- Estorno: desfaz TODOS os pagamentos da cobrança (inclusive parciais),
-- tira as entradas do caixa e a cobrança volta para "em aberto".
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
  if c.status <> 'paid' and not exists (select 1 from charge_payments where charge_id = c.id) then
    raise exception 'Esta cobrança não tem pagamento para estornar.' using errcode = '23514';
  end if;
  if not public.owns_company(c.company_id) and (
       c.approved_by is not null
       or (c.status = 'paid' and c.received_by is distinct from auth.uid())
       or exists (select 1 from charge_payments
                   where charge_id = c.id and received_by is distinct from auth.uid())) then
    raise exception 'Somente o chefe pode estornar este pagamento.' using errcode = '42501';
  end if;

  delete from cash_entries where charge_id = c.id;
  delete from charge_payments where charge_id = c.id;
  update charges set
    status = 'open', paid_at = null, payment_method = null,
    received_by = null, approved_by = null, approved_at = null
  where id = c.id
  returning * into c;
  return c;
end;
$$;

-- Relatório mensal de vendas ----------------------------------------------------
-- Pode ser gerado pelo chefe (uma empresa ou todas: p_company null) e pelos
-- funcionários (só a empresa deles, com os caixas de todos).

create or replace function public.sales_report_companies(p_company uuid)
returns setof uuid
language sql stable security definer set search_path = public as $$
  select id from companies
   where (p_company is null and owner_id = auth.uid() and public.is_owner())
      or (p_company is not null and id = p_company and public.can_manage(p_company))
$$;

-- Uma linha por lançamento do caixa no período (entradas e saídas).
-- cpf_shown: CPF do responsável se o paciente for menor de idade na data de
-- hoje; senão o CPF do paciente (ou do responsável, se o do paciente faltar).
create or replace function public.report_sales(p_company uuid, p_from date, p_to date)
returns table (
  company_name   text,
  kind           public.cash_kind,
  occurred_on    date,
  description    text,
  patient_name   text,
  guardian_name  text,
  cpf_shown      text,
  is_minor       boolean,
  payment_method text,
  installments   int,
  due_date       date,
  interest       numeric,
  amount         numeric,
  staff_name     text
)
language sql stable security definer set search_path = public as $$
  select c.name,
         e.kind,
         e.occurred_on,
         e.description,
         p.full_name,
         p.guardian_name,
         case
           when p.id is null then null
           when p.birth_date is not null and p.birth_date > (current_date - interval '18 years')::date
             then coalesce(nullif(p.guardian_cpf, ''), p.cpf)
           else coalesce(nullif(p.cpf, ''), p.guardian_cpf)
         end,
         coalesce(p.birth_date > (current_date - interval '18 years')::date, false),
         e.payment_method,
         coalesce(cp.installments, 1),
         ch.due_date,
         coalesce(cp.interest, 0),
         e.amount,
         pr.full_name
    from cash_entries e
    join companies c on c.id = e.company_id
    left join charge_payments cp on cp.id = e.payment_id
    left join charges ch on ch.id = e.charge_id
    left join patients p on p.id = coalesce(e.patient_id, ch.patient_id)
    left join profiles pr on pr.id = e.staff_id
   where e.company_id in (select public.sales_report_companies(p_company))
     and e.occurred_on between p_from and p_to
   order by e.kind, e.occurred_on, e.created_at
$$;

-- Atendimentos do período: total (sem cancelados e sem faltas) e faltas.
create or replace function public.report_sales_appointments(p_company uuid, p_from date, p_to date)
returns table (attended bigint, missed bigint)
language sql stable security definer set search_path = public as $$
  select count(*) filter (where a.status in ('scheduled', 'confirmed', 'done')),
         count(*) filter (where a.status = 'missed')
    from appointments a
   where a.company_id in (select public.sales_report_companies(p_company))
     and (a.starts_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
$$;

commit;
