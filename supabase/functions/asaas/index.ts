// Gera e cancela boletos no Asaas para as cobranças dos clientes.
//
// Chamada pelo app (chefe ou funcionário logado):
//   { "action": "create", "charge_id": "<charges.id>" }
//   { "action": "cancel", "charge_id": "<charges.id>" }
//
// Leituras e gravações usam a sessão de quem chamou: o RLS continua valendo
// e o funcionário só gera boletos da própria empresa.
//
// Segredos: ASAAS_API_KEY, ASAAS_ENV ("sandbox" ou "production").
// Deploy: supabase functions deploy asaas --no-verify-jwt

import { asaas, AsaasError, todayInBrazil } from "../_shared/asaas.ts";
import { corsHeaders, errorResponse, HttpError, json, requireUser, userClient } from "../_shared/http.ts";

function onlyDigits(value: unknown): string {
  return String(value ?? "").replace(/\D/g, "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabase = userClient(req);
    await requireUser(supabase);

    const { action, charge_id: chargeId } = await req.json();
    if (!chargeId) throw new HttpError("Cobrança não informada.");

    const { data: charge, error: chargeError } = await supabase
      .from("charges").select("*").eq("id", chargeId).maybeSingle();
    if (chargeError) throw chargeError;
    if (!charge) throw new HttpError("Cobrança não encontrada.", 404);

    const { data: canManage, error: manageError } = await supabase
      .rpc("can_manage", { p_company: charge.company_id });
    if (manageError) throw manageError;
    if (!canManage) throw new HttpError("Apenas a equipe da empresa gera boletos.", 403);

    if (action === "cancel") {
      if (!charge.asaas_payment_id) throw new HttpError("Esta cobrança não tem boleto.");
      if (charge.status === "paid") throw new HttpError("Boleto já pago não pode ser cancelado.");
      await asaas(`/payments/${charge.asaas_payment_id}`, { method: "DELETE" });
      const { error } = await supabase.from("charges").update({
        asaas_payment_id: null,
        boleto_url: null,
        invoice_url: null,
        boleto_barcode: null,
      }).eq("id", chargeId);
      if (error) throw error;
      return json({ ok: true });
    }

    if (action !== "create") throw new HttpError("Ação inválida.");
    if (charge.status !== "open") throw new HttpError("Só cobranças em aberto podem gerar boleto.");
    if (charge.asaas_payment_id) return json({ charge }); // não cobra duas vezes

    // Cliente no Asaas (criado uma vez e reaproveitado).
    const { data: patient, error: patientError } = await supabase
      .from("patients")
      .select("id, full_name, cpf, guardian_name, guardian_cpf, phone, email, asaas_customer_id")
      .eq("id", charge.patient_id)
      .single();
    if (patientError) throw patientError;

    let customerId: string | null = patient.asaas_customer_id;
    if (!customerId) {
      // Menor de idade: o boleto sai no nome e CPF do responsável.
      const ownCpf = onlyDigits(patient.cpf);
      const guardianCpf = onlyDigits(patient.guardian_cpf);
      const useGuardian = !ownCpf && !!guardianCpf;
      const cpf = useGuardian ? guardianCpf : ownCpf;
      if (cpf.length !== 11 && cpf.length !== 14) {
        throw new HttpError("Cadastre o CPF do cliente (ou do responsável) antes de gerar o boleto.");
      }
      const phone = onlyDigits(patient.phone);
      const customer = await asaas<{ id: string }>("/customers", {
        method: "POST",
        body: {
          name: useGuardian && patient.guardian_name ? patient.guardian_name : patient.full_name,
          cpfCnpj: cpf,
          email: patient.email ?? undefined,
          mobilePhone: phone.length >= 10 ? phone : undefined,
          externalReference: patient.id,
        },
      });
      customerId = customer.id;
      const { error } = await supabase
        .from("patients").update({ asaas_customer_id: customerId }).eq("id", patient.id);
      if (error) throw error;
    }

    // O Asaas não aceita vencimento no passado: cobrança vencida vence hoje.
    const today = todayInBrazil();
    const dueDate = charge.due_date > today ? charge.due_date : today;

    const payment = await asaas<{ id: string; bankSlipUrl?: string; invoiceUrl?: string }>("/payments", {
      method: "POST",
      body: {
        customer: customerId,
        billingType: "BOLETO",
        value: Number(charge.amount),
        dueDate,
        description: charge.description ?? "Ortodoctor",
        externalReference: charge.id,
      },
    });

    let barcode: string | null = null;
    try {
      const field = await asaas<{ identificationField?: string }>(
        `/payments/${payment.id}/identificationField`,
      );
      barcode = field.identificationField ?? null;
    } catch (_) {
      // A linha digitável pode demorar alguns segundos; o PDF já tem o código.
    }

    const { data: updated, error: updateError } = await supabase
      .from("charges")
      .update({
        asaas_payment_id: payment.id,
        boleto_url: payment.bankSlipUrl ?? null,
        invoice_url: payment.invoiceUrl ?? null,
        boleto_barcode: barcode,
      })
      .eq("id", chargeId)
      .select()
      .single();
    if (updateError) {
      // Não deixa boleto "solto" no Asaas se o banco recusar a gravação.
      await asaas(`/payments/${payment.id}`, { method: "DELETE" }).catch(() => {});
      throw updateError;
    }
    return json({ charge: updated });
  } catch (error) {
    if (error instanceof AsaasError) {
      return json({ error: error.message }, error.status >= 500 ? 502 : 400);
    }
    return errorResponse(error);
  }
});
