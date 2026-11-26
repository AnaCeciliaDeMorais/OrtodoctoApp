-- Meu perfil: o gestor (chefe) e o funcionário alteram o próprio nome e
-- telefone; o paciente só o telefone (update_my_phone). Roda DEPOIS de
-- test_pagamentos.sql e das migrações 20261118000000 e 20261126000000.

\set ON_ERROR_STOP 1

-- Gestor (Chefe Um) muda o próprio nome e telefone
reset role;
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000001', false);
set role authenticated;
select public.update_my_profile('Ana Gestora', '(11) 98888-7777');
select public.t_count($$select 1 from profiles where id = auth.uid()
  and full_name = 'Ana Gestora' and phone = '11988887777' and role = 'owner'$$, 1);
select public.update_my_profile('Ana Gestora', '');
select public.t_count($$select 1 from profiles where id = auth.uid() and phone is null$$, 1);
select public.t_fail($$select public.update_my_profile('', '11988887777')$$);
select public.t_fail($$select public.update_my_profile('Ana', '123')$$);
-- continua sem poder mudar o próprio perfil de acesso
select public.t_fail($$update profiles set role = 'staff' where id = auth.uid()$$);
select public.t_fail($$update profiles set active = false where id = auth.uid()$$);
reset role;

-- Funcionário: igual a antes (nome e telefone)
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000003', false);
set role authenticated;
select public.update_my_profile('Beta do Centro 2', '11999990000');
select public.t_count($$select 1 from profiles where id = auth.uid() and full_name = 'Beta do Centro 2'$$, 1);
reset role;

-- Paciente: nome não muda por aqui; telefone só por update_my_phone
select set_config('request.jwt.claim.sub', '11111111-0000-0000-0000-000000000009', false);
set role authenticated;
select public.t_fail($$select public.update_my_profile('Outro Nome', '11977776666')$$);
select public.t_fail($$update profiles set full_name = 'Outro Nome' where id = auth.uid()$$);
select public.update_my_phone('11977776666');
select public.t_count($$select 1 from profiles where id = auth.uid() and phone = '11977776666' and full_name = 'X'$$, 1);
reset role;

-- Sem login não chama a função
set role anon;
select public.t_fail($$select public.update_my_profile('A', '')$$);
reset role;

\echo '=== TESTES DO MEU PERFIL PASSARAM ==='
