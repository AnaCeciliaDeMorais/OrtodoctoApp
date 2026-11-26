#!/bin/sh
# Uso: sh run.sh  (Postgres local em /tmp porta 5499)
set -e
cd "$(dirname "$0")"
P="psql -h ${PGHOST:-/tmp} -p 5499 -U postgres -v ON_ERROR_STOP=1 -q"
$P -c 'drop database if exists ortotest' -c 'create database ortotest'
$P -d ortotest -f supabase_stub.sql
$P -d ortotest -f ../migrations/20261021000000_esquema_inicial.sql
$P -d ortotest -f test_rls.sql
$P -d ortotest -f ../migrations/20261117000000_pagamentos_e_relatorio_vendas.sql
$P -d ortotest -f test_pagamentos.sql
$P -d ortotest -f ../migrations/20261118000000_dados_do_paciente.sql
$P -d ortotest -f ../migrations/20261126000000_perfil_do_gestor.sql
$P -d ortotest -f test_perfil_gestor.sql
