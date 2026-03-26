#!/usr/bin/env bash
###############################################################################
#  Start baseline + optimized (local dev)
#  Usage: bash scripts/start.sh [--analyze]
###############################################################################
set -uo pipefail   # pas de -e : on gère les erreurs manuellement
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

#podman compose down --remove-orphans 2>/dev/null || true
podman compose down --remove-orphans 2>/dev/null || true
mintty --title "Podman Compose" -e bash -c "cd '$ROOT' && podman compose up --build --force-recreate; read -p 'Appuyez sur Entrée pour fermer...'" &

echo "⏳ Attente du démarrage des services 20s..."
sleep 20

ANALYZE=false
if [[ "${1:-}" == "--analyze" ]]; then
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
bash "$ROOT/scripts/green-score-analyzer_withdiscovery.sh" || true

echo "Press Ctrl+C to stop."
trap - EXIT    # désactive le cleanup auto, on attend manuellement
wait

