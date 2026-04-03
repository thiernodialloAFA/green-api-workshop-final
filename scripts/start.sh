#!/usr/bin/env bash
###############################################################################
#  Start baseline + optimized (local dev)
#  Usage: bash scripts/start.sh [--analyze] [--debug]
###############################################################################
set -uo pipefail   # pas de -e : on gère les erreurs manuellement
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Parse options
DEBUG_FLAG=""
for arg in "$@"; do
  case "$arg" in
    --debug) DEBUG_FLAG="--debug" ;;
  esac
done

# Détection automatique : docker ou podman ?
source "$ROOT/scripts/_container-runtime.sh"

# Suppress Podman "Executing external compose provider" warning (ignoré si docker)
export PODMAN_COMPOSE_WARNING_LOGS=false

# Force kill + remove all existing containers
$CONTAINER_COMPOSE down --remove-orphans --timeout 5 2>/dev/null || true
$CONTAINER_RT rm -f $($CONTAINER_RT ps -aq) 2>/dev/null || true

echo "⏳ Attente de 15s pour laisser les ports se libérer..."
sleep 15
echo "⏳ Attention nous allons ouvrir un terminal à coté pour lancer le compose, ne fermez pas ce terminal sauf à la fin en faisant Ctrl + C!"

if [[ "$(uname -s)" == Darwin ]]; then
  # macOS : ouvrir un nouveau Terminal.app via osascript
  osascript -e "tell application \"Terminal\" to do script \"cd '$ROOT' && $CONTAINER_COMPOSE up --build --force-recreate \""
else
  # Windows (Git Bash / mintty) : ouvrir un nouveau terminal mintty
  mintty --title "Container Compose" -e bash -c "cd '$ROOT' && $CONTAINER_COMPOSE up --build --force-recreate; read -p 'Appuyez sur Entrée pour fermer...'" &
fi

echo "⏳ Attente du démarrage des services 20s..."
sleep 20

ANALYZE=false
if [[ "${1:-}" == "--analyze" ]] || [[ "${2:-}" == "--analyze" ]]; then
  ANALYZE=true
fi

# --- Attente du démarrage des 2 services (max 30s) ---
echo ""
echo "⏳ Attente du démarrage des services (max 30s)..."
TIMEOUT=30
ELAPSED=0
BASE_READY=false
OPT_READY=false

while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
  # Vérifier que les processus tournent encore

  if ! $BASE_READY; then
    if curl -sf http://localhost:8080/actuator/health >/dev/null 2>&1; then
      BASE_READY=true
      echo "  ✅ Baseline (8080) prêt après ${ELAPSED}s"
    fi
  fi
  if ! $OPT_READY; then
    if curl -sf http://localhost:8081/actuator/health >/dev/null 2>&1; then
      OPT_READY=true
      echo "  ✅ Optimized (8081) prêt après ${ELAPSED}s"
    fi
  fi

  if $BASE_READY && $OPT_READY; then
    echo "🚀 Les 2 services sont démarrés !"
    break
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

if ! $BASE_READY || ! $OPT_READY; then
  echo ""
  echo "⚠️  Timeout (${TIMEOUT}s) — services non prêts :"
  $BASE_READY || echo "    ❌ Baseline (8080) non disponible"
  $OPT_READY || echo "    ❌ Optimized (8081) non disponible"
  echo ""
  echo "🛑 Arrêt — l'analyse ne sera pas lancée."
  exit 1
fi
echo ""

echo "Running Green Score analyzer..."
bash "$ROOT/scripts/green-score-analyzer_withdiscovery.sh" $DEBUG_FLAG || true

echo "Press Ctrl+C to stop."
trap - EXIT    # désactive le cleanup auto, on attend manuellement
wait