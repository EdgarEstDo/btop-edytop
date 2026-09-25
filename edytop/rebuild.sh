#!/usr/bin/env bash
# edytop · recompila el fork y (opcionalmente) lo rebasa sobre upstream.
#
#   ./edytop/rebuild.sh                  → compila la rama actual (make -j)
#   UPDATE_UPSTREAM=1 ./edytop/rebuild.sh → git fetch upstream + rebase upstream/main antes de compilar
#   BRANCH=otra ./edytop/rebuild.sh      → usa otra rama local
#
# Salida: bin/btop (lo que consume el lanzador edytop)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

BRANCH="${BRANCH:-edytop-xe}"

if ! git rev-parse --verify --quiet "$BRANCH" >/dev/null; then
	echo "rebuild: no existe la rama '$BRANCH'; usa BRANCH=... o créala" >&2
	exit 1
fi
git checkout --quiet "$BRANCH"

if [ "${UPDATE_UPSTREAM:-0}" = 1 ]; then
	if ! git remote get-url upstream >/dev/null 2>&1; then
		git remote add upstream https://github.com/aristocratos/btop.git
	fi
	git fetch upstream --quiet
	git rebase upstream/main
fi

JOBS="$( (nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) )"
make -j"$JOBS"

echo
echo "✔ Compilado: $REPO_DIR/bin/btop"
echo "  Instala el lanzador con: install -Dm755 edytop/edytop ~/.local/bin/edytop"
