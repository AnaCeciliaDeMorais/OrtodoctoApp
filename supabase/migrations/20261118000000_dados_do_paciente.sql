-- =============================================================================
-- 18/11/2026 — Meus dados do paciente
-- O paciente só altera o próprio telefone (e a senha, pelo Supabase Auth).
-- Nome, CPF, nascimento, endereço etc. só o chefe ou o funcionário alteram.
-- Rodar uma vez no SQL Editor do Supabase (pode rodar de novo sem problema).
-- =============================================================================

begin;

-- 1) Telefone: atualiza o perfil e todas as fichas do próprio paciente.
--    SECURITY DEFINER porque o paciente não tem permissão de UPDATE em
--    patients (policy patients_update é só da equipe); a função só mexe no
--    telefone e só nas linhas do próprio usuário.
create or replace function public.update_my_phone(p_phone text)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_phone text := nullif(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), '');
begin
  if auth.uid() is null then
    raise exception 'Faça login novamente.' using errcode = '42501';
  end if;
  if v_phone is not null and length(v_phone) not between 10 and 11 then
    raise exception 'Telefone inválido: informe DDD + número.' using errcode = '22023';
  end if;
  update profiles set phone = v_phone where id = auth.uid();
  update patients set phone = v_phone where user_id = auth.uid();
end;
$$;

revoke all on function public.update_my_phone(text) from public, anon;
grant execute on function public.update_my_phone(text) to authenticated;

-- 2) Perfil: cliente não altera o próprio nome pelo app (só a clínica).
--    Mesma função de antes, com a regra nova no bloco do próprio usuário.
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
    if old.role = 'client' and new.full_name is distinct from old.full_name then
      raise exception 'Seu nome só pode ser alterado pela clínica.' using errcode = '42501';
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

-- A ficha (patients) já é protegida: as policies patients_insert/update/delete
-- só liberam para a equipe da empresa (can_manage). O paciente só lê.

commit;
