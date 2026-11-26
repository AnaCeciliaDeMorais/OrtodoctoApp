-- =============================================================================
-- 26/11/2026 — Meu perfil do gestor e do funcionário
-- O gestor (chefe) e o funcionário alteram o próprio nome e telefone em
-- "Mais > Meu perfil". O paciente continua só com o telefone (update_my_phone).
-- Rodar uma vez no SQL Editor do Supabase (pode rodar de novo sem problema).
-- =============================================================================

begin;

-- A função passa a rodar com permissão própria (SECURITY DEFINER), assim o
-- salvamento não depende das permissões da tabela no projeto. Ela só mexe em
-- nome e telefone, só na linha do próprio usuário, e só para chefe/funcionário
-- ativos.
create or replace function public.update_my_profile(p_full_name text, p_phone text)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_name  text := nullif(trim(coalesce(p_full_name, '')), '');
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), '');
  v_row   public.profiles;
begin
  if auth.uid() is null then
    raise exception 'Faça login novamente.' using errcode = '42501';
  end if;

  select * into v_row from profiles where id = auth.uid();
  if not found or not v_row.active then
    raise exception 'Este acesso está desativado.' using errcode = '42501';
  end if;
  if v_row.role not in ('owner', 'staff') then
    raise exception 'Seu nome só pode ser alterado pela clínica.' using errcode = '42501';
  end if;

  if v_name is null then
    raise exception 'Informe o nome.' using errcode = '22023';
  end if;
  if v_phone is not null and length(v_phone) not between 10 and 11 then
    raise exception 'Telefone inválido: informe DDD + número.' using errcode = '22023';
  end if;

  update profiles
     set full_name = v_name,
         phone = v_phone
   where id = auth.uid()
  returning * into v_row;
  return v_row;
end;
$$;

revoke all on function public.update_my_profile(text, text) from public, anon;
grant execute on function public.update_my_profile(text, text) to authenticated;

commit;
