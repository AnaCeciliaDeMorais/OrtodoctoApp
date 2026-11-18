-- Testes das regras de acesso do Ortodoctor v3 (Postgres local + supabase_stub.sql).
-- Cada bloco entra como um usuário (role authenticated + auth.uid()) e confere
-- o que ele consegue ver e fazer. Qualquer falha interrompe o script.

\set ON_ERROR_STOP 1

create function public.t_fail(q text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    raise notice 'ok (bloqueado): %', left(sqlerrm, 90);
    return;
  end;
  raise exception 'DEVERIA FALHAR: %', q;
end $$;

create function public.t_count(q text, expected int) returns void language plpgsql as $$
declare n int;
begin
  execute 'select count(*) from (' || q || ') x' into n;
  if n <> expected then
    raise exception 'esperado %, veio %: %', expected, n, q;
  end if;
end $$;

-- Usuários --------------------------------------------------------------------
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
 ('11111111-0000-0000-0000-000000000001', 'chefe1@t.com', '{"role":"owner"}', '{"full_name":"Chefe Um"}'),
 ('11111111-0000-0000-0000-000000000002', 'chefe2@t.com', '{"role":"owner"}', '{"full_name":"Chefe Dois"}'),
 -- tentativa de virar chefe pelos metadados do app: deve virar cliente
 ('11111111-0000-0000-0000-000000000009', 'espertinho@t.com', '{}', '{"full_name":"X","role":"owner"}');

select public.t_count($$select 1 from profiles where role = 'owner'$$, 2);
select public.t_count($$select 1 from profiles where id = '11111111-0000-0000-0000-000000000009' and role = 'client'$$, 1);

-- Chefe 1 cria duas empresas, chefe 2 cria uma
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
insert into companies (id, owner_id, name, max_per_slot) values
 ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Clínica Centro', 2),
 ('22222222-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', 'Clínica Norte', 2)
returning id;  -- o app usa insert + select (RETURNING)
-- não pode criar empresa em nome de outro chefe
select public.t_fail($$insert into companies (owner_id, name) values ('11111111-0000-0000-0000-000000000002', 'X')$$);
reset role;

select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000002', false);
set role authenticated;
insert into companies (id, owner_id, name) values
 ('22222222-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000002', 'Outra Rede');
select public.t_count($$select 1 from companies$$, 1);
reset role;

-- cliente comum não cria empresa
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000009', false);
set role authenticated;
select public.t_fail($$insert into companies (owner_id, name) values ('11111111-0000-0000-0000-000000000009', 'X')$$);
reset role;

-- Funcionários (criados pela Edge Function com app_metadata)
insert into auth.users (id, email, raw_app_meta_data, raw_user_meta_data) values
 ('11111111-0000-0000-0000-000000000003', 'beta.centro@t.com', '{"role":"staff","company_id":"22222222-0000-0000-0000-000000000001"}', '{"full_name":"Beta Centro"}'),
 ('11111111-0000-0000-0000-000000000004', 'beta.norte@t.com',  '{"role":"staff","company_id":"22222222-0000-0000-0000-000000000002"}', '{"full_name":"Beta Norte"}'),
 ('11111111-0000-0000-0000-000000000005', 'beta.inativo@t.com','{"role":"staff","company_id":"22222222-0000-0000-0000-000000000001"}', '{"full_name":"Beta Inativo"}'),
 ('11111111-0000-0000-0000-000000000006', 'cliente.centro@t.com', '{"role":"client"}', '{"full_name":"Cliente Centro"}'),
 ('11111111-0000-0000-0000-000000000007', 'cliente.norte@t.com',  '{"role":"client"}', '{"full_name":"Cliente Norte"}');

-- Como o Auth real faz: cria o usuário e só depois grava o app_metadata
insert into auth.users (id, email, raw_user_meta_data) values
 ('11111111-0000-0000-0000-000000000008', 'beta.tardio@t.com', '{"full_name":"Beta Tardio"}');
update auth.users set raw_app_meta_data = '{"role":"staff","company_id":"22222222-0000-0000-0000-000000000002","provider":"email"}'
 where id = '11111111-0000-0000-0000-000000000008';
select public.t_count($$select 1 from profiles where id = '11111111-0000-0000-0000-000000000008' and role = 'staff' and company_id = '22222222-0000-0000-0000-000000000002'$$, 1);
-- atualização sem "role" no app_metadata não muda o perfil
update auth.users set raw_app_meta_data = '{"provider":"email"}' where id = '11111111-0000-0000-0000-000000000008';
select public.t_count($$select 1 from profiles where id = '11111111-0000-0000-0000-000000000008' and role = 'staff'$$, 1);

-- Chefe desativa um funcionário
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
update profiles set active = false where id = '11111111-0000-0000-0000-000000000005';
select public.t_count($$select 1 from profiles where role = 'staff'$$, 4);
-- chefe não pode promover funcionário a chefe
select public.t_fail($$update profiles set role = 'owner' where id = '11111111-0000-0000-0000-000000000003'$$);
-- chefe não pode mover funcionário para empresa de outro chefe
select public.t_fail($$update profiles set company_id = '22222222-0000-0000-0000-000000000003' where id = '11111111-0000-0000-0000-000000000003'$$);
-- chefe define dias de atendimento
insert into clinic_days (company_id, day, start_time, end_time) values
 ('22222222-0000-0000-0000-000000000001', '2026-11-03', '08:00', '12:00');
reset role;

-- Funcionário do Centro -------------------------------------------------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
select public.t_count($$select 1 from companies$$, 1);
-- não pode se reativar / mudar de empresa / virar chefe
select public.t_fail($$update profiles set role = 'owner' where id = auth.uid()$$);
select public.t_fail($$update profiles set company_id = '22222222-0000-0000-0000-000000000002' where id = auth.uid()$$);
select public.update_my_profile('Beta do Centro', '11999990000');
-- RN.3: dias de atendimento só o chefe
select public.t_fail($$insert into clinic_days (company_id, day) values ('22222222-0000-0000-0000-000000000001', '2026-11-04')$$);
select public.t_count($$select 1 from clinic_days$$, 1);

insert into patients (id, company_id, full_name, cpf, user_id) values
 ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 'Paciente Centro', '11122233344', '11111111-0000-0000-0000-000000000003'),
 ('33333333-0000-0000-0000-000000000002', '22222222-0000-0000-0000-000000000001', 'Outro Centro', null, null),
 ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000001', 'Terceiro Centro', null, null);
-- user_id informado pelo app é ignorado (vínculo só pela Edge Function)
select public.t_count($$select 1 from patients where user_id is not null$$, 0);
-- não cadastra cliente em outra empresa
select public.t_fail($$insert into patients (company_id, full_name) values ('22222222-0000-0000-0000-000000000002', 'Intruso')$$);
select public.t_fail($$update patients set user_id = auth.uid() where id = '33333333-0000-0000-0000-000000000001'$$);

-- Agenda: no máximo 2 pacientes no mesmo horário (RF.8)
insert into appointments (company_id, patient_id, starts_at) values
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', '2026-11-03 09:00-03'),
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002', '2026-11-03 09:00-03');
select public.t_fail($$insert into appointments (company_id, patient_id, starts_at) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000003', '2026-11-03 09:00-03')$$);
select public.t_fail($$insert into appointments (company_id, patient_id, starts_at) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', '2026-11-03 09:00-03')$$);
-- cancelado libera a vaga
update appointments set status = 'canceled' where patient_id = '33333333-0000-0000-0000-000000000002';
insert into appointments (company_id, patient_id, starts_at) values
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000003', '2026-11-03 09:00-03');

-- Cobranças e parcelamento
select public.t_count($$select * from public.create_installments('33333333-0000-0000-0000-000000000001', 'Aparelho', 1000, 3, '2026-01-31')$$, 3);
select public.t_count($$select 1 from charges where amount = 333.33$$, 2);
select public.t_count($$select 1 from charges where amount = 333.34 and due_date = '2026-03-31'$$, 1);
select public.t_count($$select 1 from charges where due_date = '2026-02-28'$$, 1);
-- não dá baixa direto (só pela função)
select public.t_fail($$update charges set status = 'paid' where installment_number = 1$$);
select public.t_fail($$insert into charges (company_id, patient_id, description, amount, due_date, status) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'x', 10, current_date, 'paid')$$);
-- recebe a parcela 1 (etapa 1)
select public.pay_charge((select id from charges where installment_number = 1), 'Pix', '2026-01-31');
select public.t_count($$select 1 from cash_entries where staff_id = auth.uid() and amount = 333.33$$, 1);
select public.t_fail($$select public.pay_charge((select id from charges where installment_number = 1), 'Pix')$$);
-- lançamento de recebimento não pode ser apagado à mão
select public.t_fail($$delete from cash_entries where charge_id is not null$$);
select public.t_fail($$update charges set amount = 1 where installment_number = 1$$);
-- estorno e novo recebimento
select public.reverse_charge((select id from charges where installment_number = 1));
select public.t_count($$select 1 from cash_entries$$, 0);
select public.pay_charge((select id from charges where installment_number = 1), 'Dinheiro', '2026-02-01');
select public.pay_charge((select id from charges where installment_number = 2), 'Cartão', '2026-03-01');
-- funcionário não aprova (etapa 2 é do chefe)
select public.t_fail($$select public.approve_charge((select id from charges where installment_number = 1))$$);
-- caixa manual próprio
insert into cash_entries (company_id, staff_id, kind, amount, description, occurred_on) values
 ('22222222-0000-0000-0000-000000000001', auth.uid(), 'out', 50, 'Material', '2026-02-10');
-- não lança no caixa de outra pessoa
select public.t_fail($$insert into cash_entries (company_id, staff_id, kind, amount, description) values ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'in', 10, 'x')$$);
-- produtos com promoção
insert into products (company_id, name, price, promo_price, is_promotion, featured) values
 ('22222222-0000-0000-0000-000000000001', 'Clareamento', 500, 399, true, true),
 ('22222222-0000-0000-0000-000000000001', 'Escova', 30, null, false, false),
 ('22222222-0000-0000-0000-000000000001', 'Inativo', 30, null, false, false);
update products set active = false where name = 'Inativo';
-- imagem do produto no Storage (só na pasta da própria empresa)
insert into storage.objects (bucket_id, name) values ('products', '22222222-0000-0000-0000-000000000001/a.jpg');
select public.t_fail($$insert into storage.objects (bucket_id, name) values ('products', '22222222-0000-0000-0000-000000000002/a.jpg')$$);
reset role;

-- Funcionário da Norte: não vê nada do Centro --------------------------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000004', false);
set role authenticated;
select public.t_count($$select 1 from patients$$, 0);
select public.t_count($$select 1 from appointments$$, 0);
select public.t_count($$select 1 from charges$$, 0);
select public.t_count($$select 1 from cash_entries$$, 0);
select public.t_count($$select 1 from products$$, 0);
select public.t_count($$select 1 from companies$$, 1);
select public.t_fail($$select public.pay_charge((select id from charges limit 1), 'Pix')$$);
-- relatórios só para chefe
select public.t_count($$select * from public.report_revenue_by_month(null, '2026-01-01', '2026-12-31')$$, 0);
insert into patients (id, company_id, full_name) values
 ('33333333-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000002', 'Paciente Norte');
reset role;

-- Funcionário inativo: perde todo acesso -------------------------------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000005', false);
set role authenticated;
select public.t_count($$select 1 from patients$$, 0);
select public.t_count($$select 1 from companies$$, 0);
select public.t_fail($$insert into patients (company_id, full_name) values ('22222222-0000-0000-0000-000000000001', 'X')$$);
reset role;

-- Vínculo do login do cliente (feito pela Edge Function com chave de serviço)
set role service_role;
select set_config('request.jwt.claim.role', 'service_role', false);
update patients set user_id = '11111111-0000-0000-0000-000000000006' where id = '33333333-0000-0000-0000-000000000001';
update patients set user_id = '11111111-0000-0000-0000-000000000007' where id = '33333333-0000-0000-0000-000000000004';
select set_config('request.jwt.claim.role', '', false);
reset role;

-- Cliente do Centro -----------------------------------------------------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000006', false);
set role authenticated;
select public.t_count($$select 1 from patients$$, 1);
select public.t_count($$select 1 from appointments$$, 1);
select public.t_count($$select 1 from charges$$, 3);
select public.t_count($$select 1 from cash_entries$$, 0);
select public.t_count($$select 1 from products$$, 2);  -- inativo não aparece
select public.t_count($$select 1 from companies$$, 1);
select public.t_count($$select 1 from clinic_days$$, 1);
-- RN.10 / RN.11
select public.t_fail($$select public.pay_charge((select id from charges where status = 'open' limit 1), 'Pix')$$);
select public.t_fail($$insert into appointments (company_id, patient_id, starts_at) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', '2026-11-03 10:00-03')$$);
update charges set description = 'x', status = 'canceled';  -- RLS: nenhuma linha muda
select public.t_count($$select 1 from charges where description = 'x' or status = 'canceled'$$, 0);
-- dúvidas (RF.16)
insert into questions (company_id, patient_id, message, answer) values
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'Posso remarcar?', 'auto-resposta');
select public.t_count($$select 1 from questions where answer is null$$, 1);
select public.t_fail($$insert into questions (company_id, patient_id, message) values ('22222222-0000-0000-0000-000000000002', '33333333-0000-0000-0000-000000000004', 'oi')$$);
reset role;

-- Cliente da Norte não vê nada do Centro
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000007', false);
set role authenticated;
select public.t_count($$select 1 from charges$$, 0);
select public.t_count($$select 1 from questions$$, 0);
select public.t_count($$select 1 from products$$, 0);
reset role;

-- Funcionário responde a dúvida
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
update questions set answer = 'Sim, pelo telefone.';
select public.t_count($$select 1 from questions where answered_by = auth.uid() and answered_at is not null$$, 1);
reset role;

-- Chefe 1: vê tudo das duas empresas, aprova e tira relatórios ---------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
select public.t_count($$select 1 from patients$$, 4);
select public.t_count($$select 1 from cash_entries$$, 3);
select public.approve_charge((select id from charges where installment_number = 1));
select public.t_count($$select 1 from charges where approved_by = auth.uid()$$, 1);
-- funcionário não estorna o que o chefe já aprovou; chefe pode
select public.t_count($$select * from public.report_revenue_by_month(null, '2026-01-01', '2026-12-31')$$, 2);
select public.t_count($$select * from public.report_revenue_by_month('22222222-0000-0000-0000-000000000002', '2026-01-01', '2026-12-31')$$, 0);
select public.t_count($$select * from public.report_overdue(null, '2026-10-21')$$, 1);
select public.t_count($$select * from public.report_appointments(null, '2026-11-01', '2026-11-30')$$, 2);
select public.t_count($$select * from public.report_cash_by_staff(null, '2026-01-01', '2026-12-31') where approved_two_step = 1 and pending_approval = 1$$, 1);
-- chefe 1 não vê empresa do chefe 2 nem nos relatórios
select public.t_count($$select * from public.report_revenue_by_month('22222222-0000-0000-0000-000000000003', '2026-01-01', '2026-12-31')$$, 0);
reset role;

select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
select public.t_fail($$select public.reverse_charge((select id from charges where installment_number = 1))$$);
select public.reverse_charge((select id from charges where installment_number = 2));
reset role;

-- Chefe 2 não vê nada do chefe 1
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000002', false);
set role authenticated;
select public.t_count($$select 1 from patients$$, 0);
select public.t_count($$select 1 from cash_entries$$, 0);
select public.t_count($$select 1 from profiles$$, 1);
select public.t_fail($$select public.approve_charge((select id from charges limit 1))$$);
reset role;

-- Anônimo (sem login) não vê nada
set role anon;
select set_config('request.jwt.claim.sub', '', false);
select public.t_count($$select 1 from products$$, 0);
reset role;

-- Pasta do paciente: boletos anexados ---------------------------------------
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
insert into storage.objects (bucket_id, name) values
 ('patient-files', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001/boleto-3.pdf'),
 ('patient-files', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000002/boleto-x.pdf');
insert into patient_files (company_id, patient_id, charge_id, title, file_path, file_name, content_type) values
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', (select id from charges where installment_number = 3), 'Boleto parcela 3',
  '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001/boleto-3.pdf', 'boleto-3.pdf', 'application/pdf'),
 ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002', null, 'Boleto avaliação', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000002/boleto-x.pdf', 'boleto-x.pdf', 'application/pdf');
-- arquivo fora da pasta do cliente / cobrança de outro cliente
select public.t_fail($$insert into patient_files (company_id, patient_id, title, file_path, file_name) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'x', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000002/y.pdf', 'y.pdf')$$);
select public.t_fail($$insert into patient_files (company_id, patient_id, charge_id, title, file_path, file_name) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000002', (select id from charges where installment_number = 3), 'x', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000002/z.pdf', 'z.pdf')$$);
-- caminho que não é de paciente da empresa
select public.t_fail($$insert into storage.objects (bucket_id, name) values ('patient-files', '22222222-0000-0000-0000-000000000001/qualquer/a.pdf')$$);
select public.t_fail($$insert into storage.objects (bucket_id, name) values ('patient-files', '22222222-0000-0000-0000-000000000002/33333333-0000-0000-0000-000000000004/a.pdf')$$);
select public.t_count($$select 1 from storage.objects where bucket_id = 'patient-files'$$, 2);
reset role;

-- Cliente do Centro vê e baixa só o boleto dele; não envia nem apaga
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000006', false);
set role authenticated;
select public.t_count($$select 1 from patient_files$$, 1);
select public.t_count($$select 1 from storage.objects where bucket_id = 'patient-files'$$, 1);
select public.t_count($$select 1 from charges c join patient_files f on f.charge_id = c.id$$, 1);
select public.t_fail($$insert into storage.objects (bucket_id, name) values ('patient-files', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001/meu.pdf')$$);
select public.t_fail($$insert into patient_files (company_id, patient_id, title, file_path, file_name) values ('22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'x', '22222222-0000-0000-0000-000000000001/33333333-0000-0000-0000-000000000001/x.pdf', 'x.pdf')$$);
delete from patient_files;  -- RLS: nada é apagado
reset role;
select public.t_count($$select 1 from patient_files$$, 2);

-- Cliente e funcionário da Norte não veem os arquivos do Centro
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000007', false);
set role authenticated;
select public.t_count($$select 1 from patient_files$$, 0);
select public.t_count($$select 1 from storage.objects where bucket_id = 'patient-files'$$, 0);
reset role;
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000004', false);
set role authenticated;
select public.t_count($$select 1 from patient_files$$, 0);
select public.t_count($$select 1 from storage.objects where bucket_id = 'patient-files'$$, 0);
reset role;

-- Chefe vê todos os arquivos das empresas dele
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
select public.t_count($$select 1 from patient_files$$, 2);
select public.t_count($$select 1 from storage.objects where bucket_id = 'patient-files'$$, 2);
reset role;

\echo '=== TODOS OS TESTES PASSARAM ==='
