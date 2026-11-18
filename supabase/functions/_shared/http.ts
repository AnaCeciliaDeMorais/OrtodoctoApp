import { createClient, SupabaseClient, User } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Cliente com a chave de serviço (ignora o RLS). Use só depois de checar permissões. */
export function adminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

/** Cliente com a sessão de quem chamou: o RLS continua valendo. */
export function userClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
}

/** Usuário logado que chamou a função (erro 401 se não houver). */
export async function requireUser(client: SupabaseClient): Promise<User> {
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new HttpError("Faça login novamente.", 401);
  return data.user;
}

/** RN.7: mínimo 8 caracteres, 1 número e 1 caractere especial. */
export function checkPassword(password: unknown): string {
  const p = String(password ?? "");
  if (p.length < 8) throw new HttpError("A senha precisa ter pelo menos 8 caracteres.");
  if (!/\d/.test(p)) throw new HttpError("A senha precisa ter pelo menos 1 número.");
  if (!/[^A-Za-z0-9]/.test(p)) throw new HttpError("A senha precisa ter pelo menos 1 caractere especial.");
  return p;
}

export function checkEmail(email: unknown): string {
  const e = String(email ?? "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e)) throw new HttpError("E-mail inválido.");
  return e;
}

export function errorResponse(error: unknown) {
  if (error instanceof HttpError) return json({ error: error.message }, error.status);
  console.error(error);
  const message = error instanceof Error
    ? error.message
    : (error as { message?: string })?.message ?? "Erro inesperado.";
  return json({ error: message }, 500);
}
