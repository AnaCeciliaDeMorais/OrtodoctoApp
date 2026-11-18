// Cria e remove logins (o app não tem a chave de serviço, por isso passa por aqui).
//
// Ações (corpo JSON, campo "action"):
//   register_owner        cadastro de chefe (RF.17); exige o segredo OWNER_SIGNUP_CODE
//   create_staff          chefe cria funcionário numa empresa dele (RF.2)
//   delete_staff          chefe exclui funcionário (RN.6)
//   create_client_access  chefe ou funcionário cria o login do cliente e liga à ficha
//   remove_client_access  tira o acesso do cliente
//
// Segredos: OWNER_SIGNUP_CODE (código para criar conta de gestor).
// Deploy: supabase functions deploy admin-users --no-verify-jwt
//   (o login é conferido aqui dentro; register_owner é chamado sem login)

import {
  adminClient,
  checkEmail,
  checkPassword,
  corsHeaders,
  errorResponse,
  HttpError,
  json,
  requireUser,
  userClient,
} from "../_shared/http.ts";

type Body = Record<string, unknown>;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const body = (await req.json()) as Body;
    switch (body.action) {
      case "register_owner":
        return await registerOwner(body);
      case "create_staff":
        return await createStaff(req, body);
      case "delete_staff":
        return await deleteStaff(req, body);
      case "create_client_access":
        return await createClientAccess(req, body);
      case "remove_client_access":
        return await removeClientAccess(req, body);
      default:
        throw new HttpError("Ação inválida.");
    }
  } catch (error) {
    return errorResponse(error);
  }
});

const admin = adminClient();

function text(v: unknown): string | null {
  const s = String(v ?? "").trim();
  return s ? s : null;
}

async function emailInUse(email: string) {
  const { data, error } = await admin.from("profiles").select("id, role").ilike("email", email).maybeSingle();
  if (error) throw error;
  return data as { id: string; role: string } | null;
}

function authError(error: { message?: string; code?: string }): never {
  const msg = error.message ?? "";
  if (error.code === "email_exists" || /already been registered|already exists/i.test(msg)) {
    throw new HttpError("Este e-mail já tem acesso ao app.");
  }
  if (error.code === "weak_password") throw new HttpError("Senha fraca.");
  throw new HttpError(msg || "Não foi possível criar o acesso.");
}

async function registerOwner(body: Body) {
  const expected = Deno.env.get("OWNER_SIGNUP_CODE");
  if (!expected) throw new HttpError("Cadastro de gestor desativado.", 403);
  if (String(body.signup_code ?? "").trim() !== expected) {
    throw new HttpError("Código de cadastro inválido.", 403);
  }
  const email = checkEmail(body.email);
  const password = checkPassword(body.password);
  const fullName = text(body.full_name);
  if (!fullName) throw new HttpError("Informe o nome.");

  const { error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { role: "owner" },
    user_metadata: { full_name: fullName, phone: text(body.phone) },
  });
  if (error) authError(error);
  return json({ ok: true });
}

/** Confere que quem chamou é chefe ativo e dono da empresa. */
async function requireOwnerOf(req: Request, companyId: string) {
  const client = userClient(req);
  const user = await requireUser(client);
  const { data, error } = await client.rpc("owns_company", { p_company: companyId });
  if (error) throw error;
  if (!data) throw new HttpError("Somente o chefe da empresa pode fazer isso.", 403);
  return user;
}

async function createStaff(req: Request, body: Body) {
  const companyId = text(body.company_id);
  if (!companyId) throw new HttpError("Empresa não informada.");
  await requireOwnerOf(req, companyId);

  const email = checkEmail(body.email);
  const password = checkPassword(body.password);
  const fullName = text(body.full_name);
  if (!fullName) throw new HttpError("Informe o nome.");
  if (await emailInUse(email)) throw new HttpError("Este e-mail já tem acesso ao app.");

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    app_metadata: { role: "staff", company_id: companyId },
    user_metadata: { full_name: fullName, phone: text(body.phone) },
  });
  if (error) authError(error);
  return json({ ok: true, user_id: data.user?.id });
}

async function deleteStaff(req: Request, body: Body) {
  const userId = text(body.user_id);
  if (!userId) throw new HttpError("Funcionário não informado.");
  const { data: target, error } = await admin
    .from("profiles").select("id, role, company_id").eq("id", userId).maybeSingle();
  if (error) throw error;
  if (!target || target.role !== "staff" || !target.company_id) {
    throw new HttpError("Funcionário não encontrado.", 404);
  }
  await requireOwnerOf(req, target.company_id);

  const { count } = await admin
    .from("cash_entries").select("id", { count: "exact", head: true }).eq("staff_id", userId);
  if ((count ?? 0) > 0) {
    throw new HttpError(
      "Este funcionário tem lançamentos no caixa. Desative o acesso para manter o histórico.",
    );
  }
  const { error: delError } = await admin.auth.admin.deleteUser(userId);
  if (delError) throw new HttpError(delError.message);
  return json({ ok: true });
}

/** Lê a ficha com a sessão de quem chamou e confere que ele gerencia a empresa. */
async function requireManagerOfPatient(req: Request, patientId: string) {
  const client = userClient(req);
  await requireUser(client);
  const { data: patient, error } = await client
    .from("patients").select("id, company_id, user_id, full_name").eq("id", patientId).maybeSingle();
  if (error) throw error;
  if (!patient) throw new HttpError("Cliente não encontrado.", 404);
  const { data: ok, error: e2 } = await client.rpc("can_manage", { p_company: patient.company_id });
  if (e2) throw e2;
  if (!ok) throw new HttpError("Sem permissão para este cliente.", 403);
  return patient as { id: string; company_id: string; user_id: string | null; full_name: string };
}

async function createClientAccess(req: Request, body: Body) {
  const patientId = text(body.patient_id);
  if (!patientId) throw new HttpError("Cliente não informado.");
  const patient = await requireManagerOfPatient(req, patientId);
  if (patient.user_id) throw new HttpError("Este cliente já tem acesso.");

  const email = checkEmail(body.email);
  let userId: string;
  let created = false;

  const existing = await emailInUse(email);
  if (existing) {
    // Mesmo cliente em outra empresa (ou responsável por mais de um paciente).
    if (existing.role !== "client") {
      throw new HttpError("Este e-mail pertence a um funcionário ou gestor.");
    }
    userId = existing.id;
  } else {
    const password = checkPassword(body.password);
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { role: "client" },
      user_metadata: { full_name: patient.full_name },
    });
    if (error) authError(error);
    userId = data.user!.id;
    created = true;
  }

  const { error: linkError } = await admin
    .from("patients").update({ user_id: userId, email }).eq("id", patient.id);
  if (linkError) {
    // Não deixa login "solto" se a ficha não pôde ser ligada.
    if (created) await admin.auth.admin.deleteUser(userId);
    throw linkError;
  }
  return json({ ok: true, reused: !created });
}

async function removeClientAccess(req: Request, body: Body) {
  const patientId = text(body.patient_id);
  if (!patientId) throw new HttpError("Cliente não informado.");
  const patient = await requireManagerOfPatient(req, patientId);
  const userId = patient.user_id;
  if (!userId) return json({ ok: true });

  const { error } = await admin.from("patients").update({ user_id: null }).eq("id", patient.id);
  if (error) throw error;

  // Apaga o login se ele não estiver ligado a nenhuma outra ficha.
  const { count } = await admin
    .from("patients").select("id", { count: "exact", head: true }).eq("user_id", userId);
  const { data: profile } = await admin.from("profiles").select("role").eq("id", userId).maybeSingle();
  if ((count ?? 0) === 0 && profile?.role === "client") {
    // As dúvidas continuam na ficha (author_id vira nulo).
    const { error: delError } = await admin.auth.admin.deleteUser(userId);
    // A ficha já foi desligada; sem ficha o login não vê nada.
    if (delError) console.error("remove_client_access deleteUser", delError);
  }
  return json({ ok: true });
}
