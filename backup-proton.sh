#!/usr/bin/env bash
#
# ============================================================
#  Sauvegarde chiffrée Proton Drive — version robuste (corrigée)
#  Dossier + sous-dossiers, multi-sources, gestion d'erreurs,
#  verrou anti-exécutions simultanées, notification d'échec.
#
#  Dépendances : proton-drive CLI (binaire), pass, jq, curl (optionnel),
#                mail ou mailx (optionnel)
#  Flux : https://proton.me/support/drive-cli
#
#  NOTE SCHÉMA JSON : Proton ne publie pas de catalogue officiel des
#  codes d'erreur JSON du CLI. Les expressions jq ci-dessous sont
#  volontairement tolérantes (champs .error, .status, .errors).
#  Après un premier échec réel, vérifiez la sortie dans le log et
#  adaptez la fonction analyze_upload_json si nécessaire.
# ============================================================

set -uo pipefail   # pas de "-e" : on gère les erreurs manuellement

# ------------------------- Configuration -------------------------

# PATH explicite : indispensable en cron où le PATH est minimal
export PATH="/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"

DRIVE_BIN="/usr/local/bin/proton-drive"    # chemin du binaire CLI proton-drive
LOG_DIR="/var/log/proton-backup"
LOCK_FILE="/tmp/proton-backup.lock"
STALE_LOCK_HOURS=6                          # verrou plus vieux = considéré orphelin

# Options d'upload : à valider avec `proton-drive filesystem upload --help`.
# Pour de gros volumes sans images, ajouter --skip-thumbnails (plus rapide).
UPLOAD_EXTRA_FLAGS="--skip-thumbnails"

# Sources à sauvegarder : "chemin_local:destination_dans_drive"
SOURCES=(
  "${HOME}/Nextcloud/dev:/my-files/backups"
  "${HOME}/Nextcloud/personnel/JHB/dev:/my-files/backups"
  "${HOME}/Nextcloud/personnel/JHB/livres:/my-files/medias"
  "${HOME}/Nextcloud/documents:/my-files/backups/cd03"
)

# Notifications d'échec (laisser vide pour désactiver)
MAIL_TO="admin@example.com"                 # destinataire (mail ou mailx)
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
FAILED_SOURCES=()   # vide ; l'expansion est protégée par un garde ci-dessous

# ------------------------- Fonctions -------------------------

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

die_usage() {
  log "ERREUR FATALE : $*"
  exit 2
}

notify_failure() {
  local subject="[backup] ÉCHEC sauvegarde Proton Drive sur $(hostname)"
  local body="$1"

  # 1) Mail si configuré (mail OU mailx)
  if [[ -n "$MAIL_TO" ]]; then
    if command -v mail >/dev/null 2>&1; then
      printf '%s\n' "$body" | mail -s "$subject" "$MAIL_TO" \
        || log "AVERTISSEMENT : envoi du mail de notification impossible"
    elif command -v mailx >/dev/null 2>&1; then
      printf '%s\n' "$body" | mailx -s "$subject" "$MAIL_TO" \
        || log "AVERTISSEMENT : envoi du mailx de notification impossible"
    else
      log "AVERTISSEMENT : MAIL_TO défini mais ni mail ni mailx trouvé"
    fi
  fi

  # 2) Webhook si configuré (JSON générique Slack/Discord/Gotify)
  if [[ -n "$WEBHOOK_URL" ]] && command -v curl >/dev/null 2>&1; then
    local payload
    payload=$(jq -n --arg t "$subject" --arg b "$body" '{text: "\($t)\n\($b)"}')
    curl -fsS --max-time 15 -H 'Content-Type: application/json' \
         -d "$payload" "$WEBHOOK_URL" >/dev/null 2>&1 \
      || log "AVERTISSEMENT : appel du webhook impossible"
  fi
}

cleanup() {
  # Piège global : s'assure que le verrou est toujours retiré
  rm -rf "$LOCK_FILE"
}

on_int()  { cleanup; log "Interrompu (SIGINT)";  exit 130; }
on_term() { cleanup; log "Interrompu (SIGTERM)"; exit 143; }

# Analyse la sortie JSON d'un upload et renvoie le nombre d'anomalies.
# Tolérante aux variantes de schéma : champ .error non nul, champ .errors
# non vide, ou .status contenant error/fail (insensible à la casse).
# NB : « (.status? // "") | test(...) » — parenthèses obligatoires car
# en jq, test() ne peut pas s'écrire « .a // .b | test » sans ambiguïté.
analyze_upload_json() {
  local json="$1"
  [[ -z "$json" ]] && { echo 0; return; }
  jq '
    [.[]?
      | select(
          (.error?  != null)
          or ((.errors? // []) | length > 0)
          or (((.status? // "") | ascii_downcase) | test("error|fail"))
        )
    ] | length
  ' <<<"$json" 2>/dev/null || echo 0
}

# Compte les fichiers réellement présents dans un listing JSON distant.
# Renvoie le nombre d'identifiants trouvés (champ .id), 0 en cas de doute.
count_remote_entries() {
  local json="$1"
  [[ -z "$json" ]] && { echo 0; return; }
  jq '[.[].id? // empty] | length' <<<"$json" 2>/dev/null || echo 0
}

# ------------------------- Préconditions -------------------------

[[ -x "$DRIVE_BIN" ]]            || die_usage "binaire CLI introuvable ou non exécutable : $DRIVE_BIN"
command -v jq >/dev/null 2>&1    || die_usage "jq requis pour parser la sortie --json"
command -v pass >/dev/null 2>&1 || die_usage "pass requis pour le stockage des identifiants en cron"

# Anti-exécutions simultanées (atomicité du lock via mkdir).
# Gestion d'un verrou orphelin (script tué par SIGKILL / reboot) :
# si le lock existe et est plus vieux que STALE_LOCK_HOURS, on le purge.
if [[ -d "$LOCK_FILE" ]]; then
  lock_age_h=$(( ( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || date +%s) ) / 3600 ))
  if (( lock_age_h >= STALE_LOCK_HOURS )); then
    log "AVERTISSEMENT : verrou orphelin détecté (${lock_age_h} h), purge."
    rm -rf "$LOCK_FILE"
  else
    log "AVERTISSEMENT : une autre instance tourne déjà (lock $LOCK_FILE), abandon."
    exit 3
  fi
fi
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  log "AVERTISSEMENT : impossible de créer le verrou $LOCK_FILE, abandon."
  exit 3
fi
trap cleanup EXIT
trap on_int  INT
trap on_term TERM

# Purge des anciens logs
find "$LOG_DIR" -name 'backup_*.log' -mtime "+$LOG_RETENTION_DAYS" -delete 2>/dev/null \
  || log "AVERTISSEMENT : impossible de purger les vieux logs"

# ------------------------- Exécution -------------------------

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
                $UPLOAD_EXTRA_FLAGS \
                --json 2>>"$LOG_FILE")"
  rc=$?

  if [[ $rc -ne 0 ]]; then
    log "ERREUR : upload de « ${src} » a échoué (exit ${rc})"
    [[ -n "$json_out" ]] && printf '%s\n' "$json_out" >> "$LOG_FILE"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  # Analyse de la sortie JSON : statut d'erreur explicite même si
  # le CLI renvoie 0 (robustesse accrue). Voir analyze_upload_json
  # pour la stratégie tolérante au schéma.
  err_count="$(analyze_upload_json "$json_out")"
  if [[ "$err_count" != "0" ]]; then
    log "ERREUR : ${err_count} anomalie(s) signalée(s) dans la sortie JSON pour « ${src} »"
    printf '%s\n' "$json_out" >> "$LOG_FILE"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  # Vérification a posteriori : listing du dossier distant.
  listing="$("$DRIVE_BIN" filesystem list "$dst" --json 2>>"$LOG_FILE")"
  if [[ $? -ne 0 ]]; then
    log "ERREUR : vérification post-upload impossible (échec du list) pour « ${dst} »"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  fi

  remote_n="$(count_remote_entries "$listing")"
  src_n="$(find "$src" -mindepth 1 2>/dev/null | wc -l)"

  # Un listing vide n'est une erreur QUE si la source n'était pas vide.
  # Une source vide est un cas légitime : simple avertissement.
  if (( src_n > 0 )) && (( remote_n == 0 )); then
    log "ERREUR : aucun fichier trouvé dans « ${dst} » alors que « ${src} » contenait ${src_n} élément(s)"
    printf '%s\n' "$listing" >> "$LOG_FILE"
    FAILED_SOURCES+=("${src}")
    EXIT_CODE=1
    continue
  elif (( remote_n == 0 )); then
    log "AVERTISSEMENT : « ${dst} » est vide, mais la source « ${src} » l'était aussi — rien à signaler."
  fi

  # NB : cette vérification atteste la présence d'entrées distantes,
  # pas leur nombre exact ni leur intégrité. Un contrôle de comptage
  # strict (src_n == remote_n) serait trop fragile (fichiers cachés,
  # dossiers imbriqués, entités système Drive).

  log "OK : ${src} sauvegardé vers ${dst} (${remote_n} entrée(s) distante(s))"
done

# ------------------------- Bilan -------------------------

if [[ $EXIT_CODE -ne 0 ]]; then
  # Garde pour bash < 4.4 : expansion d'un tableau vide interdite sous set -u
  failed_list=""
  ((${#FAILED_SOURCES[@]})) && failed_list="${FAILED_SOURCES[*]}"
  summary="La sauvegarde Proton Drive s'est terminée avec des erreurs.\nSources en échec : ${failed_list}\nLog détaillé : ${LOG_FILE}\nHôte : $(hostname) ($(date))"
  log "BILAN : ÉCHEC — sources en échec : ${failed_list}"
  notify_failure "$summary"
else
  log "BILAN : SUCCÈS — toutes les sources ont été sauvegardées."
fi

exit "$EXIT_CODE"
