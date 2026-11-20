#!/usr/bin/env bash
#
# ============================================================
#  Sauvegarde chiffrée Proton Drive — version robuste
#  Dossier + sous-dossiers, multi-sources, gestion d'erreurs,
#  verrou anti-exécutions simultanées, notification d'échec.
#
#  Dépendances : proton-drive CLI (binaire), pass, jq, curl (optionnel)
#  Testé avec le flux décrit sur https://proton.me/support/drive-cli
# ============================================================

set -uo pipefail   # pas de "-e" : on gère les erreurs manuellement pour continuer les autres sources

# ------------------------- Configuration -------------------------

DRIVE_BIN="/etc/proton-drive/proton-drive"       # chemin du binaire CLI proton-drive
LOG_DIR="/var/log/proton-backup"
LOCK_FILE="/tmp/proton-backup.lock"

# Sources à sauvegarder : "chemin_local:destination_dans_drive"
# Le contenu du dossier ET ses sous-dossiers sont envoyés récursivement.
SOURCES=(
  "${HOME}/Nextcloud/dev:/my-files/backups"
  "${HOME}/Nextcloud/personnel/JHB/dev:/my-files/backups"
  "${HOME}/Nextcloud/personnel/JHB/livres:/my-files/medias"
  "${HOME}/Nextcloud/documents:/my-files/backups/cd03"
  "/etc/scripts:/myfiles/backups/dev"
)

# Notifications d'échec (laisser vide pour désactiver)
MAIL_TO="admin@example.com"                 # destinataire mail (nécessite mail ou mailx)
WEBHOOK_URL=""                              # ex. Slack/Discord/Gotify : "" = désactivé

# Nombre de jours de rétention des logs locaux
LOG_RETENTION_DAYS=14

# -----------------------------------------------------------------

mkdir -p "$LOG_DIR"

# Identifiants : "pass" fonctionne sans session graphique (contrairement
# à libsecret/GNOME Keyring), indispensable pour les jobs cron.
export PROTON_DRIVE_CREDENTIALS_STORE="pass"

TS="$(date +%Y-%m-%d)"
LOG_FILE="${LOG_DIR}/backup_${TS}.log"

EXIT_CODE=0

# ------------------------- Fonctions -------------------------

log() {
  # Journalise horodaté et affiche sur stderr/stdout
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die_usage() {
  log "ERREUR FATALE : $*"
  exit 2
}

notify_failure() {
  local subject="[backup] ÉCHEC sauvegarde Proton Drive sur $(hostname)"
  local body="$1"

  # 1) Mail si configuré
  if [[ -n "$MAIL_TO" ]] && command -v mail >/dev/null 2>&1; then
    printf '%s\n' "$body" | mail -s "$subject" "$MAIL_TO" \
      || log "AVERTISSEMENT : envoi du mail de notification impossible"
  fi

  # 2) Webhook si configuré (JSON générique, adapté aux bots Slack/Discord/Gotify)
  if [[ -n "$WEBHOOK_URL" ]] && command -v curl >/dev/null 2>&1; then
    local payload
    payload=$(jq -n --arg t "$subject" --arg b "$body" \
              '{text: "\($t)\n\($b)"}')
    curl -fsS --max-time 15 -H 'Content-Type: application/json' \
         -d "$payload" "$WEBHOOK_URL" >/dev/null 2>&1 \
      || log "AVERTISSEMENT : appel du webhook impossible"
  fi
}

cleanup() {
  # Piège global : s'assurer que le verrou est toujours retiré
  rm -rf "$LOCK_FILE"
}

# ------------------------- Préconditions -------------------------

[[ -x "$DRIVE_BIN" ]]            || die_usage "binaire CLI introuvable ou non exécutable : $DRIVE_BIN"
command -v jq >/dev/null 2>&1    || die_usage "jq requis pour parser la sortie --json"
command -v pass >/dev/null 2>&1 || die_usage "pass requis pour le stockage des identifiants en cron"

# Anti-exécutions simultanées (atomicité du lock via mkdir)
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  log "AVERTISSEMENT : une autre instance tourne déjà (lock $LOCK_FILE), abandon."
  exit 3
fi
trap cleanup EXIT INT TERM

# Purge des anciens logs
find "$LOG_DIR" -name 'backup_*.log' -mtime "+$LOG_RETENTION_DAYS" -delete 2>/dev/null \
  || log "AVERTISSEMENT : impossible de purger les vieux logs"

# ------------------------- Exécution -------------------------

FAILED_SOURCES=()

for entry in "${SOURCES[@]}"; do
  src="${entry%%:*}"
  dst="${entry##*:}"

  if [[ ! -d "$src" ]]; then
    log "ERREUR : source inexistante « ${src} » — ignorée"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  log "Début upload : ${src} -> ${dst}"

  # Sortie JSON capturée : le code de retour ET la sortie sont analysés.
  json_out="$("$DRIVE_BIN" filesystem upload "${src}/" "$dst" \
                -d merge --file-conflict-strategy replace \
                --json 2>>"$LOG_FILE")"
  rc=$?

  if [[ $rc -ne 0 ]]; then
    log "ERREUR : upload de « ${src} » a échoué (exit ${rc})"
    [[ -n "$json_out" ]] && printf '%s\n' "$json_out" >> "$LOG_FILE"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  # Analyse de la sortie JSON : on cherche explicitement un statut d'erreur
  # même si le CLI renvoie 0 (robustesse accrue).
  err_count=$(printf '%s' "$json_out" | jq '[.[]? | select(.status? // .error? != null)] | length' 2>/dev/null || echo "0")
  if [[ "$err_count" != "0" && -n "$err_count" ]]; then
    log "ERREUR : ${err_count} anomalie(s) signalée(s) dans la sortie JSON pour « ${src} »"
    printf '%s\n' "$json_out" >> "$LOG_FILE"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  # Vérification a posteriori : le dossier distant contient bien des entrées
  listing="$("$DRIVE_BIN" filesystem list "$dst" --json 2>>"$LOG_FILE")"
  if [[ $? -ne 0 ]] || [[ -z "$(printf '%s' "$listing" | jq -r '.[].id? // empty' 2>/dev/null)" ]]; then
    log "ERREUR : vérification post-upload impossible pour « ${dst} »"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  log "OK : ${src} sauvegardé vers ${dst}"
done

# ------------------------- Bilan -------------------------

if [[ $EXIT_CODE -ne 0 ]]; then
  summary="La sauvegarde Proton Drive s'est terminée avec des erreurs.\nSources en échec : ${FAILED_SOURCES[*]}\nLog détaillé : ${LOG_FILE}\nHôte : $(hostname) ($(date))"
  log "BILAN : ÉCHEC — sources en échec : ${FAILED_SOURCES[*]}"
  notify_failure "$summary"
else
  log "BILAN : SUCCÈS — toutes les sources ont été sauvegardées."
fi

exit "$EXIT_CODE"
