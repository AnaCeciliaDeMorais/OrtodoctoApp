-- Testes de recebimento em várias formas, pagamento parcial, estorno e
-- relatório de vendas. Roda DEPOIS de test_rls.sql e da migração
-- 20261117000000_pagamentos_e_relatorio_vendas.sql (ver run.sh).

\set ON_ERROR_STOP 1

-- Backfill: a cobrança paga antes da migração ganhou o pagamento e a ligação no caixa.
select public.t_count($$select 1 from charge_payments where method = 'Dinheiro' and amount = 333.33$$, 1);
select public.t_count($$select 1 from cash_entries where charge_id is not null and payment_id is null$$, 0);

-- Paciente menor de idade com responsável, e uma cobrança para ele.
insert into patients (id, company_id, full_name, cpf, birth_date, guardian_name, guardian_cpf) values
 ('33333333-0000-0000-0000-000000000010', '22222222-0000-0000-0000-000000000001', 'Menor Centro',
  '99999999999', current_date - interval '10 years', 'Mãe do Menor', '55566677788');
insert into charges (id, company_id, patient_id, description, amount, due_date) values
 ('44444444-0000-0000-0000-000000000010', '22222222-0000-0000-0000-000000000001',
  '33333333-0000-0000-0000-000000000010', 'Aparelho', 1000, current_date);

-- Funcionário do Centro recebe 300 em Pix + 200 no cartão 3x (parcial: faltam 500).
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
select public.receive_payment('44444444-0000-0000-0000-000000000010',
  '[{"method":"Pix","amount":300},{"method":"Cartão de crédito","amount":200,"installments":3}]',
  current_date, 15);
select public.t_count($$select 1 from charges where id = '44444444-0000-0000-0000-000000000010' and status = 'open'$$, 1);
select public.t_count($$select 1 from charge_payments where charge_id = '44444444-0000-0000-0000-000000000010'$$, 2);
-- juros entram no caixa junto com a primeira forma
select public.t_count($$select 1 from cash_entries where charge_id = '44444444-0000-0000-0000-000000000010' and amount = 315 and payment_method = 'Pix'$$, 1);
-- não deixa receber mais do que falta
select public.t_fail($$select public.receive_payment('44444444-0000-0000-0000-000000000010', '[{"method":"Pix","amount":600}]')$$);
-- não deixa excluir nem cancelar com pagamento parcial
select public.t_fail($$delete from charges where id = '44444444-0000-0000-0000-000000000010'$$);
select public.t_fail($$update charges set status = 'canceled' where id = '44444444-0000-0000-0000-000000000010'$$);
select public.t_fail($$update charges set amount = 100 where id = '44444444-0000-0000-0000-000000000010'$$);
-- não grava direto na tabela de pagamentos
select public.t_fail($$insert into charge_payments (charge_id, company_id, patient_id, method, amount) values ('44444444-0000-0000-0000-000000000010', '22222222-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000010', 'Pix', 1)$$);
-- quita o restante em dinheiro
select public.receive_payment('44444444-0000-0000-0000-000000000010', '[{"method":"Dinheiro","amount":500}]', current_date, 0);
select public.t_count($$select 1 from charges where id = '44444444-0000-0000-0000-000000000010' and status = 'paid' and approved_by is null and payment_method = 'Cartão de crédito 3x + Dinheiro + Pix'$$, 1);

-- Relatório: funcionário gera o da empresa dele, não o de outra.
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000001', current_date - 400, current_date + 1) where patient_name = 'Menor Centro' and cpf_shown = '55566677788' and is_minor$$, 3);
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000002', current_date - 400, current_date + 1)$$, 0);
select public.t_count($$select 1 from public.report_sales(null, current_date - 400, current_date + 1)$$, 0);
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000001', current_date - 400, current_date + 1) where installments = 3 and interest = 0 and amount = 200$$, 1);
select public.t_count($$select 1 from public.report_sales_appointments('22222222-0000-0000-0000-000000000001', current_date - 400, current_date + 400)$$, 1);
reset role;

-- Paciente maior: CPF dele mesmo.
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000001', '2026-01-01', '2026-12-31') where patient_name = 'Paciente Centro' and cpf_shown = '11122233344'$$, 1);
-- chefe: geral (todas as empresas dele)
select public.t_count($$select 1 from public.report_sales(null, current_date - 400, current_date + 1) where company_name = 'Clínica Centro'$$, 5);
reset role;

-- Outro chefe não vê nada da empresa do Chefe Um.
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000002', false);
set role authenticated;
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000001', '2020-01-01', '2030-12-31')$$, 0);
reset role;

-- Cliente vê os pagamentos dele, mas não gera relatório.
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000006', false);
set role authenticated;
select public.t_count($$select 1 from public.report_sales('22222222-0000-0000-0000-000000000001', '2020-01-01', '2030-12-31')$$, 0);
reset role;

-- Estorno pelo funcionário que recebeu tudo e ainda não foi aprovado.
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
select public.reverse_charge('44444444-0000-0000-0000-000000000010');
select public.t_count($$select 1 from charges where id = '44444444-0000-0000-0000-000000000010' and status = 'open' and payment_method is null$$, 1);
select public.t_count($$select 1 from charge_payments where charge_id = '44444444-0000-0000-0000-000000000010'$$, 0);
select public.t_count($$select 1 from cash_entries where charge_id = '44444444-0000-0000-0000-000000000010'$$, 0);
-- parcial e estorno do parcial
select public.receive_payment('44444444-0000-0000-0000-000000000010', '[{"method":"Boleto","amount":100}]');
select public.reverse_charge('44444444-0000-0000-0000-000000000010');
select public.t_count($$select 1 from charge_payments where charge_id = '44444444-0000-0000-0000-000000000010'$$, 0);
-- agora pode excluir
delete from charges where id = '44444444-0000-0000-0000-000000000010';
reset role;

select '=== TESTES DE PAGAMENTO PASSARAM ===';
