# Ortodoctor / (nome a ser repensado)

App e site (Flutter: Android, iOS e web) para clínicas com várias empresas
Backend: Supabase (Postgres + Auth + Storage + Edge Functions).

## Perfis de acesso

| Perfil | Como entra | O que faz |
| --- | --- | --- |
| **Chefe** (Staff Alfa) | Aba **Gestor** da tela de login (acesso separado) | Cria e gerencia várias empresas, cadastra/desativa/exclui funcionários, define os dias de atendimento, vê o caixa de todos (por empresa ou geral), aprova pagamentos e tira relatórios em PDF. Também usa agenda, clientes e produtos. |
| **Funcionário** (Staff Beta) | Aba **Clínica** | Trabalha em uma empresa só: agenda, clientes, cobranças, produtos/promoções, dúvidas e **somente o próprio caixa**. |
| **Cliente** | Aba **Clínica** | Vê as próprias consultas, pagamentos (com boleto), produtos e promoções da clínica, avisos e envia dúvidas. Não agenda nem dá baixa sozinho. |

Conta de chefe só entra pela aba Gestor, e as outras só pela aba Clínica.

## O que tem em cada área

- **Agenda**: semana no topo, horários do dia conforme o horário da empresa ou os dias cadastrados pelo chefe; até N pacientes por horário (padrão 2, configurável por empresa); etiquetas e situação (agendado, confirmado, atendido, faltou, cancelado).
- **Clientes**: busca por nome/CPF/telefone, ficha com dados, consultas e financeiro; criar/remover acesso ao app; WhatsApp.
- **Cobranças**: avulsa ou parcelada; receber pagamento (entra no caixa de quem recebeu), estornar, cancelar, boleto Asaas (gerar, abrir, copiar linha digitável, cancelar; baixa automática pelo webhook).
- **Aprovação em duas etapas**: o funcionário recebe (etapa 1) e o chefe aprova (etapa 2). Os relatórios mostram quantos foram aprovados em duas etapas.
- **Caixa**: entradas e saídas por mês, PDF. Funcionário vê só o dele; chefe filtra por empresa (ou todas) e por pessoa.
- **Relatórios** (chefe): faturamento por mês, inadimplência, atendimentos por período e caixa por funcionário; uma empresa ou todas; PDF.
- **Produtos e promoções**: foto (galeria/câmera), preço, preço promocional com data limite, "fixar no topo"; promoções e fixados aparecem em destaque (carrossel e selo com % de desconto).
- **Dúvidas**: cliente pergunta, equipe responde.
- **Perfil**: nome, telefone, alterar senha, tema claro/escuro, sair. "Esqueci minha senha" com link que abre o app.

## Estrutura

```
lib/
  app/            app.dart (tela inicial por perfil), session.dart (usuário logado e empresa em uso)
  core/           config, tema, formatação, validação, erros, widgets comuns
  shared/models/  modelos (perfil, empresa, cliente, agendamento, cobrança, caixa, produto, dúvida)
  features/
    auth/         login (Clínica/Gestor), cadastro de gestor, nova senha
    home/         navegação por perfil, troca de empresa, menu "Mais"
    companies/    empresas, equipe, dias de atendimento
    schedule/     agenda
    patients/     clientes, ficha, cobranças
    cash/         caixa e PDF
    approvals/    aprovações do chefe
    reports/      relatórios e PDF
    products/     produtos e promoções
    questions/    dúvidas
    client/       telas do cliente
    profile/      perfil
supabase/
  migrations/     esquema completo do banco (um arquivo)
  functions/      admin-users (cria/remove logins), asaas, asaas-webhook
  tests/          testes das regras de acesso num Postgres local
test/             testes das regras do app
```

## Como colocar no ar

### 1. Supabase

1. Crie um projeto em https://supabase.com (grátis) e anote a **URL** e a **chave publicável** (Project Settings > API).
2. **SQL Editor** > cole `supabase/migrations/20261021000000_esquema_inicial.sql` inteiro > **Run**. Ele cria tabelas, regras de acesso (RLS ligado em tudo), funções de pagamento, relatórios e o bucket de fotos `products`.
3. **Authentication > Sign In / Providers**: desligue **Allow new users to sign up** (os acessos são criados pelo app) e deixe **Confirm email** como preferir (os acessos criados pelo app já saem confirmados).
4. **Authentication > URL Configuration**: em *Redirect URLs* adicione `br.com.ortodoctor.app://reset-password` e o endereço do site (ex.: `https://app.ortodoctor.com.br`).
5. **Authentication > Policies/Password**: mínimo de 8 caracteres com dígitos e símbolos (o app já exige: 8+ caracteres, 1 número e 1 caractere especial).
6. Edge Functions (precisa da CLI: https://supabase.com/docs/guides/cli):
   ```
   supabase login
   supabase link --project-ref <id-do-projeto>
   supabase secrets set OWNER_SIGNUP_CODE=<código-para-criar-gestor>
   supabase secrets set ASAAS_API_KEY=<chave> ASAAS_ENV=sandbox ASAAS_WEBHOOK_TOKEN=<token>
   supabase functions deploy admin-users --no-verify-jwt
   supabase functions deploy asaas --no-verify-jwt
   supabase functions deploy asaas-webhook --no-verify-jwt
   ```
   No Asaas: Integrações > Webhooks > URL `https://<projeto>.supabase.co/functions/v1/asaas-webhook`, token igual ao `ASAAS_WEBHOOK_TOKEN`, eventos de cobrança recebida/confirmada. Use `ASAAS_ENV=production` quando sair do teste.

### 2. Primeiro acesso

1. Abra o app, aba **Gestor** > **Criar conta de gestor** e use o `OWNER_SIGNUP_CODE`.
2. Cadastre a empresa (Mais > Empresas e equipe), os funcionários e, se quiser, os dias de atendimento.
3. Na ficha de cada cliente, **Criar acesso ao app** gera o login dele.

### 3. Rodar e compilar

Informe a URL e a chave do Supabase (ou preencha os valores padrão em `lib/core/config.dart`):

```
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_xxxx
flutter build web --release   --dart-define=...   (site: publique a pasta build/web)
flutter build appbundle       --dart-define=...   (Play Store)
flutter build ipa             --dart-define=...   (App Store, num Mac)
```

### 4. Lojas

- Identificador: `br.com.ortodoctor.app` (Android e iOS).
- Assinatura Android: crie a chave (`keytool -genkey -v -keystore ortodoctor.jks -keyalg RSA -keysize 2048 -validity 10000 -alias ortodoctor`) e o arquivo `android/key.properties` com `storePassword`, `keyPassword`, `keyAlias` e `storeFile`. Não envie esses arquivos para o git.
- Falta antes de publicar: ícone e tela de abertura próprios (hoje são os padrão do Flutter) e uma política de privacidade (exigida pelas lojas e pela LGPD).

## Testes

- `flutter analyze` e `flutter test` (regras de senha, CPF, dinheiro, horários da agenda, promoções e aprovação).
- `supabase/tests/run.sh`: aplica o esquema num Postgres local com um "Supabase mínimo" (`supabase_stub.sql`) e testa as regras de acesso dos três perfis (`test_rls.sql`).
- Em 21/10/2026 o app também foi testado de ponta a ponta com Auth (GoTrue) e PostgREST locais: cadastro de gestor, empresa, funcionário, cliente com acesso, agenda, parcelamento, recebimento, aprovação, relatórios, produtos, dúvidas e telas dos três perfis no navegador.

## Observações

- Senhas: o Supabase guarda com bcrypt (mais seguro que MD5/SHA-1 citados no documento original).
- Backup diário (RNF.8): o plano Pro do Supabase faz backup diário automático; no plano grátis, exporte pelo painel.
- Notificações push (RF.10 a RF.13): nesta versão os avisos aparecem na tela inicial do cliente (próxima consulta, pagamentos vencidos ou vencendo, promoções). Push no celular exige configurar Firebase (Android) e Apple Push (iOS).
- Este projeto não usa o banco do app antigo. Os dados antigos não são copiados automaticamente.
