# skills

Skills pessoais para agentes de IA (Claude Code, Codex, Copilot CLI e afins).
Cada subpasta é uma skill autocontida com um `SKILL.md` (frontmatter `name` +
`description` e o corpo com as instruções).

## Skills

### `model-routing`
Roteamento de modelos e orquestração por subagents. Princípio: **opus decide,
sonnet constrói, haiku procura.** A thread principal (opus) pensa, planeja e
sintetiza; delega busca de contexto a subagents haiku (até 4 em paralelo) e
alteração de código a subagents sonnet. Inclui tabela de roteamento, fluxo de
busca (entender raso → disparar → sintetizar) e regras de julgamento sobre
quando *não* vale a pena delegar.

### `criar-pr`
Abre PR e acompanha até o destino pedido (`develop` ou `master`), esperando
**todas** as pipelines passarem. O poll é delegado a um subagent haiku (barato);
se uma pipe falha, um subagent opus diagnostica e corrige, e o haiku retoma o
acompanhamento. Para `master`, passa por `develop` primeiro. Cobre retry de
`gh` em 401 intermitente, regras de merge e formato de PR/commit.

## Instalação (symlink)

Clone o repositório uma vez e aponte o diretório de skills de cada ferramenta
para as subpastas daqui. Assim, atualizar é só `git pull` — todas as ferramentas
pegam a mudança.

```bash
git clone git@github.com:xinnaider/skills.git ~/skills
```

Cada agente lê skills de um diretório próprio (ex.: `~/.claude/skills` no Claude
Code) e exige que cada skill seja **filho direto** desse diretório — por isso é
um link por skill, não um link da pasta inteira.

### Tudo de uma vez (`install.sh`)

```bash
./install.sh                  # alvo padrão ~/.claude/skills
./install.sh ~/.codex/skills  # outro agente
```

O script percorre as subpastas que têm `SKILL.md` e cria/atualiza um symlink de
cada uma no diretório alvo.

### Manual (macOS / Linux)

```bash
ln -s ~/skills/model-routing ~/.claude/skills/model-routing
ln -s ~/skills/criar-pr      ~/.claude/skills/criar-pr
```

### Windows (PowerShell, como administrador)

```powershell
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\model-routing" -Target "$HOME\skills\model-routing"
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\skills\criar-pr"      -Target "$HOME\skills\criar-pr"
```

> Troque `~/.claude/skills` pelo diretório de skills da ferramenta que você usa
> (Codex, Copilot CLI, etc.). O alvo do link é sempre a subpasta correspondente
> em `~/skills`.

## Atualizar

```bash
cd ~/skills && git pull
```

Como as skills instaladas são symlinks para este repositório, o `pull` já
propaga as mudanças para todas as ferramentas.
