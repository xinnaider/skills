---
name: criar-pr
description: >
  Cria PR e acompanha até o destino pedido (develop ou master), aguardando
  TODAS as pipes passarem. Monitoramento delegado a um sub-agent haiku (barato,
  fica fazendo poll); se alguma pipe falhar, um sub-agent opus 4.8 diagnostica e
  corrige, e o haiku retoma o acompanhamento. Para master, passa por develop
  primeiro e depois develop→master. Use quando o usuário disser "criar pr",
  "/criar-pr", "abre PR até develop/master", "sobe pra master".
---

# criar-pr — abrir PR e acompanhar até o destino

Orquestra a abertura de PR(s) e o acompanhamento das pipelines até chegar ao
alvo solicitado. O agente principal (opus) coordena; o trabalho repetitivo de
poll é delegado a sub-agents para economizar contexto/custo.

## Entrada

O usuário informa o **alvo**:
- `develop` (padrão) — abre `feature → develop`.
- `master` — abre `feature → develop`, leva até o fim, e SÓ DEPOIS abre
  `develop → master`. Nunca pula develop.

Se o alvo não for dito, pergunte uma vez: "Até develop ou até master?".

## Pré-requisitos (verifique antes)

1. Está numa branch de feature (NÃO em `develop`/`master`). Se estiver em
   `develop`/`master`, pare e peça uma branch.
2. Há commits para subir. Se houver mudanças não commitadas, confirme com o
   usuário se devem entrar no PR; commite só com autorização.
3. `git push -u origin <branch>` feito (push usa SSH, funciona mesmo com o token
   do gh oscilando).

## gh: lidar com 401 intermitente

O `gh` neste ambiente às vezes devolve `HTTP 401`. SEMPRE rode os comandos `gh`
com retry e sem env tokens herdados:

```bash
retry_gh() { for i in 1 2 3 4 5 6; do out=$(env -u GH_TOKEN -u GITHUB_TOKEN gh "$@" 2>&1); if echo "$out" | grep -q "401"; then sleep 2; else echo "$out"; return 0; fi; done; echo "$out"; return 1; }
```

Use `retry_gh pr create ...`, `retry_gh pr merge ...`, `retry_gh run ...`, etc.

## Fluxo

### 1. Abrir o PR da feature → develop
- `retry_gh pr create --base develop --head <branch> --title "<conv-commit>" --body "<resumo>"`.
- Guarde o número do PR.

### 2. Acompanhar as pipes (sub-agent HAIKU)
Delegue o poll a um sub-agent **haiku** (`model: haiku`, `subagent_type:
general-purpose`). Ele NÃO conserta nada — só observa e relata. Prompt sugerido:

> Monitore o PR #<n> do repositório (gh). A cada ~30s rode
> `env -u GH_TOKEN -u GITHUB_TOKEN gh pr checks <n>` (retry em 401). Quando todos
> os checks obrigatórios saírem de pending/queued, PARE e retorne um resumo:
> lista de checks com status (pass/fail) e, para cada fail, o nome do job e o
> link. Não tente corrigir nada. Limite ~20 tentativas.

Rode esse sub-agent em background se preferir seguir trabalhando.

### 3. Se algum check FALHOU (sub-agent OPUS 4.8)
Delegue o conserto a um sub-agent **opus** (`model: opus`,
`subagent_type: general-purpose`, `isolation: worktree` se mexer em código).
Passe: número do PR, branch, nome do(s) job(s) que falharam e o link do log.
Prompt sugerido:

> A pipe do PR #<n> (branch <branch>) falhou no job "<job>". Baixe o log
> (`gh run view --job <jobId> --log-failed`), descubra a causa, corrija na
> branch <branch>, rode o typecheck/teste local relevante até passar, commite
> com mensagem convencional e dê push. Não mude escopo além do necessário para a
> pipe ficar verde. Retorne o que mudou e o resultado local.

Depois do push, **volte ao passo 2** (haiku) e acompanhe a nova execução.
Repita 2↔3 até todos os checks ficarem verdes.

### 4. Merge em develop
- Com tudo verde: `retry_gh pr merge <n> --merge`.
- Confirme `state == MERGED`.

### 5. Se o alvo for master: release develop → master
- `retry_gh pr create --base master --head develop --title "chore(release): ... → master" --body "..."`.
- Repita passos 2–4 para ESTE PR (haiku acompanha, opus corrige se quebrar,
  merge no fim).
- Confirme `MERGED`.

### 6. Encerrar
Pare quando o alvo pedido (develop OU master) estiver mergeado e verde. Reporte:
- PRs abertos (números), destino, estado final
- Quantas correções foram necessárias (e o que o opus mudou, se mudou)
- Confirmação das pipes verdes no destino

## Regras
- Nunca mergeie em master sem antes passar/mergear em develop.
- Nunca force-merge com check vermelho. Se não der pra consertar em ~3 ciclos
  opus, pare e reporte ao usuário com o diagnóstico.
- O haiku só observa; o opus só conserta; o merge é decisão do agente principal.
- Mensagens de PR/commit em português, formato Conventional Commits.
