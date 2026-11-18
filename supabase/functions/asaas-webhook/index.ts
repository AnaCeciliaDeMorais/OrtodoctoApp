// Recebe os avisos do Asaas e dá baixa automática quando o boleto é pago.
//
// Cadastro no Asaas: Integrações > Webhooks > URL
//   https://<projeto>.supabase.co/functions/v1/asaas-webhook
// com o "Token de autenticação" igual ao segredo ASAAS_WEBHOOK_TOKEN e os
// eventos de cobrança (PAYMENT_RECEIVED, PAYMENT_CONFIRMED).
//
// Deploy (o Asaas não envia login do Supabase, por isso sem verificação de JWT):
//   supabase functions deploy asaas-webhook --no-verify-jwt

import { createClient } from "npm:@supabase/supabase-js@2";
import { todayInBrazil } from "../_shared/asaas.ts";

const PAID_EVENTS = new Set(["PAYMENT_RECEIVED", "PAYMENT_CONFIRMED"]);

Deno.serve(async (req) => {
  const expected = Deno.env.get("ASAAS_WEBHOOK_TOKEN");
  if (!expected || req.headers.get("asaas-access-token") !== expected) {
    return new Response("unauthorized", { status: 401 });
  }

  let body: { event?: string; payment?: Record<string, string> };
  try {
    body = await req.json();
  } catch (_) {
    return new Response("invalid body", { status: 400 });
  }

  // Eventos que não são pagamento são apenas confirmados (o Asaas pausa a fila
  // de webhooks quando recebe erros seguidos).
  if (!body.event || !PAID_EVENTS.has(body.event) || !body.payment?.id) {
    return Response.json({ ignored: body.event ?? null });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const paymentDate = body.payment.paymentDate ??
    body.payment.clientPaymentDate ??
    body.payment.confirmedDate ??
    todayInBrazil();

  const { data, error } = await admin.rpc("pay_charge_from_asaas", {
    p_asaas_payment_id: body.payment.id,
    p_paid_on: paymentDate,
  });

  if (error) {
    console.error("pay_charge_from_asaas", error);
    // Erro no banco: devolve 500 para o Asaas reenviar depois.
    return new Response("database error", { status: 500 });
  }
  return Response.json({ result: data });
});
