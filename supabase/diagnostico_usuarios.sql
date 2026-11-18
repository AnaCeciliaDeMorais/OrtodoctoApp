-- =============================================================================
-- Diagnóstico de login / exclusão de usuários (SOMENTE LEITURA)
-- Como usar: Supabase > SQL Editor > colar tudo > Run. Não altera nada.
-- =============================================================================

-- 1) Estado de cada login (auth.users) e do perfil do app (public.profiles).
--    Usuário criado "na mão" por SQL costuma ter aud/role vazios, tokens nulos
--    ou nenhuma identidade -> o login quebra e o painel não consegue apagar.
select
  u.email,
  u.id,
  u.aud,                                         -- esperado: authenticated
  u.role,                                        -- esperado: authenticated
  u.email_confirmed_at is not null               as email_confirmado,
  u.confirmation_token is null                   as token_conf_nulo,     -- esperado: false
  u.recovery_token is null                       as token_rec_nulo,      -- esperado: false
  u.email_change is null                         as email_change_nulo,   -- esperado: false
  u.email_change_token_new is null               as ect_nulo,            -- esperado: false
  u.raw_app_meta_data,                           -- esperado: {"role": "owner"|"staff"|"client", ...}
  (select count(*) from auth.identities i where i.user_id = u.id) as identidades, -- esperado: 1
  p.id is not null                               as tem_perfil,          -- esperado: true
  p.role                                         as perfil_role,
  p.active                                       as perfil_ativo,
  p.company_id                                   as perfil_empresa
from auth.users u
left join public.profiles p on p.id = u.id
order by u.created_at;

-- 2) O que impede apagar cada login ("Database error deleting user").
--    companies.owner_id e cash_entries.staff_id são ON DELETE RESTRICT:
--    um chefe que ainda tem empresa, ou alguém com lançamento no caixa,
--    não pode ser apagado até esses registros saírem.
select
  u.email,
  (select count(*) from public.companies c    where c.owner_id  = u.id) as empresas_do_chefe,
  (select count(*) from public.cash_entries ce where ce.staff_id = u.id) as lancamentos_caixa
from auth.users u
order by u.created_at;

-- 3) Perfis sem login correspondente (sobras de exclusões).
select p.* from public.profiles p
where not exists (select 1 from auth.users u where u.id = p.id);
