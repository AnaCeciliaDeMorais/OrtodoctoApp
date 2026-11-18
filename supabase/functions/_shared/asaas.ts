// Cliente mínimo da API do Asaas (https://docs.asaas.com).
//
// Segredos (Supabase > Edge Functions > Secrets):
//   ASAAS_API_KEY        chave de API da conta Asaas
//   ASAAS_ENV            "sandbox" (testes) ou "production"
//   ASAAS_WEBHOOK_TOKEN  token escolhido ao cadastrar o webhook no Asaas

const BASE_URL = Deno.env.get("ASAAS_ENV") === "production"
  ? "https://api.asaas.com/v3"
  : "https://api-sandbox.asaas.com/v3";

export class AsaasError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

export async function asaas<T = Record<string, unknown>>(
  path: string,
  init: { method?: string; body?: unknown } = {},
): Promise<T> {
  const apiKey = Deno.env.get("ASAAS_API_KEY");
  if (!apiKey) {
    throw new AsaasError("ASAAS_API_KEY não configurada no Supabase.", 500);
  }

  const response = await fetch(`${BASE_URL}${path}`, {
    method: init.method ?? "GET",
    headers: {
      "access_token": apiKey,
      "Content-Type": "application/json",
      "User-Agent": "Ortodoctor",
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const errors = (data?.errors ?? []) as { description?: string }[];
    const message = errors.map((e) => e.description).filter(Boolean).join(" ") ||
      `Erro ${response.status} no Asaas.`;
    throw new AsaasError(message, response.status);
  }
  return data as T;
}

/** Data de hoje no fuso de Brasília, no formato AAAA-MM-DD. */
export function todayInBrazil(): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Sao_Paulo",
  }).format(new Date());
}
