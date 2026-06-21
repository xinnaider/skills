#!/usr/bin/env bash
# Instala (symlink) toda skill deste repo no diretório de skills do agente.
# Cada skill precisa ser filho DIRETO do dir de skills (skills/<nome>/SKILL.md),
# por isso um link por skill — o loop faz todos de uma vez.
#
# Uso:
#   ./install.sh                       # alvo padrão ~/.claude/skills
#   ./install.sh ~/.codex/skills       # outro agente
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-$HOME/.claude/skills}"
mkdir -p "$DEST"

for dir in "$REPO"/*/; do
  [ -f "$dir/SKILL.md" ] || continue          # só pastas que são skill
  name="$(basename "$dir")"
  ln -sfn "$dir" "$DEST/$name"                 # -f sobrescreve, -n não segue link existente
  echo "linked $name -> $DEST/$name"
done
