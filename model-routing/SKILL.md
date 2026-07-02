---
name: model-routing
description: >-
  Roteamento de modelos e orquestração por subagents. Use SEMPRE que for
  trabalhar em código de forma não-trivial — implementar feature, corrigir bug,
  refatorar, ou buscar/mapear contexto no codebase — mesmo que o usuário não
  peça explicitamente para delegar. Dispare esta skill ao iniciar qualquer
  tarefa de engenharia multi-step, ao procurar onde algo está definido ou quem
  usa o quê, ao reunir contexto antes de editar, ou ao decidir como dividir o
  trabalho entre subagents.
---

# Model Routing

Você (a thread principal) roda no **modelo principal da sessão** — o que o
usuário selecionou (Fable, Opus, Sonnet, qualquer um). Não assuma um modelo
fixo: o system prompt do harness diz qual é o modelo atual, e a regra vale para
qualquer um. Seu trabalho não é fazer tudo sozinho — é pensar, planejar e
orquestrar, delegando cada pedaço para o tier certo. Modelo caro pensando é bom
investimento; modelo caro fazendo grep não é.

A ideia central: **o modelo principal decide, um tier médio constrói, um tier
barato procura.** Cada tarefa no tier apropriado economiza custo e tempo sem
perder qualidade.

## Tabela de roteamento

| Tipo de trabalho | Modelo | Como |
|---|---|---|
| Pensar, planejar, decidir, orquestrar, sintetizar resultado final | **modelo principal da sessão** | Você mesmo, na thread principal. Não delegue isso. |
| Desenvolver / alterar código — feature, bugfix, refactor, testes | **sonnet** (padrão) | Subagent com `model: "sonnet"` |
| Código crítico — algoritmo delicado, refactor arriscado, bug cabeludo | **modelo principal da sessão** | Subagent **sem** o parâmetro `model` (herda o da sessão) |
| Vasculhar código / reunir contexto — achar onde algo está, listar usos, mapear pasta | **haiku** | Subagent com `model: "haiku"` |

Delegação é via tool `Agent` (ou `Task`), passando o override `model`. O
`subagent_type` define as ferramentas disponíveis; o `model` define quem
executa. Os valores aceitos dependem do harness (ex.: `sonnet`, `opus`,
`haiku`, `fable`). **Omitir `model` faz o subagent herdar o modelo principal da
sessão** — é o jeito de usar o modelo atual num subagent sem hardcodar nome, e
continua correto quando o usuário trocar de modelo.

**Pedido explícito do usuário vence a tabela.** "Usa fable nesse subagent",
"roda tudo em haiku", "não delega" — obedeça sem discutir.

**Pensar é sempre seu — nunca delegado.** Não spawne subagent para decidir,
planejar, julgar ou escolher o que fazer. Decisão, plano e síntese ficam no
agent atual. Subagent existe só para *executar*: tier barato busca, tier médio
altera código. Quem decide o que buscar e o que mudar é você. Em particular,
não crie um subagent para "pensar" — isso é o seu trabalho na thread principal.

## Buscar contexto: entenda raso primeiro, depois dispare

Nunca dispare uma frota de subagents às cegas. O fluxo é sempre:

1. **Entenda superficialmente você mesmo.** Uma orientação rápida — olhar a
   estrutura da pasta, abrir um arquivo-chave, formar hipóteses sobre onde a
   coisa mora. Isso é barato e faz você escrever prompts de busca muito mais
   afiados. Subagent com prompt vago devolve lixo; subagent com alvo claro
   devolve ouro.

2. **Dispare subagents haiku em paralelo — no máximo 4.** Quebre a busca em
   threads independentes (ex: "onde X é definido", "quem chama X", "onde está a
   config de Y", "mapeie o módulo Z") e mande cada uma para um subagent. Escolha
   a quantidade pela quantidade de fios independentes que existem de verdade —
   1, 2, 3 ou 4. Não invente trabalho para encher 4 vagas, e nunca passe de 4.

3. **Sintetize você mesmo.** Junte o que voltou, decida o próximo passo. Essa
   parte é pensamento — fica no modelo principal.

Subagents de busca recomendados (todos com `model: "haiku"`):
- `Explore` — fan-out amplo, read-only, devolve a conclusão sem despejar
  arquivos inteiros.
- `cavecrew-investigator` — localizador read-only, saída comprimida (tabela
  `file:line`), ~60% menos tokens de volta na sua context. Use se disponível.

**Exemplo** (três fios independentes → três subagents):
```
Agent(subagent_type="Explore", model="haiku",
      description="achar definição de X",
      prompt="Localize onde a classe/função X é definida. Devolva file:line e assinatura.")
Agent(subagent_type="cavecrew-investigator", model="haiku",
      description="quem chama X",
      prompt="Liste todos os call sites de X. Tabela file:line, sem sugerir fixes.")
Agent(subagent_type="Explore", model="haiku",
      description="mapear config Y",
      prompt="Onde fica a config de Y e como é carregada? Conclusão, não dump.")
```
Dispare os independentes na mesma leva (em paralelo), não um de cada vez.

## Alterar código: delegue para o tier certo

Implementação — escrever/editar código, feature, bugfix, refactor, testes — vai
para subagent. Dê ao subagent o contexto que você já levantou (caminhos,
decisões, restrições) para ele não redescobrir tudo do zero.

- **Trabalho comum** (feature normal, bugfix claro, testes): `model: "sonnet"`.
- **Trabalho crítico** (algoritmo delicado, refactor arriscado, concorrência,
  bug que já resistiu a uma tentativa): omita `model` — o subagent herda o
  modelo principal da sessão.

Subagents de código recomendados:
- `cavecrew-builder` — edição cirúrgica de 1-2 arquivos (typo, rewrite de
  função, rename mecânico). Recusa escopo de 3+ arquivos. Use se disponível.
- `general-purpose` — features maiores, vários arquivos, escopo amplo.

## Julgamento: nem tudo merece um subagent

A regra de roteamento existe para o trabalho ter peso suficiente para pagar o
overhead de subir um subagent. Use a cabeça:

- **Edição trivial** (uma linha, um typo que você já está olhando): faça você
  mesmo. Subir um subagent para trocar um caractere custa mais do que rende.
- **Leitura pontual** de um arquivo que você já sabe onde está: só leia. O fluxo
  de busca com subagents é para quando você *não* sabe onde procurar ou são
  vários fios.
- **Quando em dúvida, delegue.** O ponto da skill é não deixar o modelo caro
  fazendo trabalho braçal de busca/implementação que um tier menor faz por
  menos.

O princípio acima da regra: cada peça no modelo certo. As regras servem a esse
princípio — não as siga ao ponto de gastar mais do que economizam.
