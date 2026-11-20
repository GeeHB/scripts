#!/usr/bin/env bash
#===============================================================================
#  montage.sh
#
#  Montage « à la demande » du partage NFS du mediacenter.
#
#  Équivalent de cette ligne /etc/fstab :
#     192.168.1.171:/media/data/nextcloud  /mnt/share  nfs  defaults  0 0
#
#  Usage :
#     ./montage.sh              # monte le partage (action par défaut)
#     ./montage.sh monter
#     ./montage.sh demonter
#     ./montage.sh basculer     # démonte si monté, monte sinon
#     ./montage.sh statut
#
#  Pour l'appeler sans mot de passe, ajoutez une règle sudoers dédiée :
#     sudo visudo -f /etc/sudoers.d/nfs-mediacenter
#       <votre_user> ALL=(root) NOPASSWD: /usr/local/bin/montage-nfs.sh
#===============================================================================

set -uo pipefail

#------------------------------ Paramètres ------------------------------------
SERVEUR="192.168.1.171"          # IP du mediacenter
EXPORT="/media/data/nextcloud"   # chemin exporté côté serveur
POINT_MONTAGE="/mnt/share"       # point de montage local
TYPE_FS="nfs"                    # type de système de fichiers
OPTIONS="defaults"               # options de montage (identiques à fstab)

DELAI_PING=2                     # délai max du ping, en secondes
ESSAIS=3                         # nombre de tentatives de montage
DELAI_ESSAI=2                    # pause entre deux tentatives, en secondes

SOURCE="${SERVEUR}:${EXPORT}"

#-------------------------------- Outils --------------------------------------
SUDO=""
[[ ${EUID} -ne 0 ]] && SUDO="sudo"

horodate() { date '+%Y-%m-%d %H:%M:%S'; }
info()     { printf '[%s] %s\n' "$(horodate)" "$*"; }
erreur()   { printf '[%s] ERREUR : %s\n' "$(horodate)" "$*" >&2; }

#------------------------------ Fonctions -------------------------------------

est_monte() {
    mountpoint -q -- "$POINT_MONTAGE"
}

serveur_joignable() {
    ping -c 1 -W "$DELAI_PING" -- "$SERVEUR" >/dev/null 2>&1
}

export_disponible() {
    # Vérification facultative : le serveur annonce-t-il bien cet export ?
    # (nécessite nfs-common ; ignorée silencieusement si absente)
    command -v showmount >/dev/null 2>&1 || return 0
    showmount -e "$SERVEUR" 2>/dev/null | grep -qF -- "$EXPORT"
}

monter() {
    if est_monte; then
        info "« $POINT_MONTAGE » est déjà monté. Rien à faire."
        return 0
    fi

    if ! serveur_joignable; then
        erreur "Le serveur $SERVEUR ne répond pas au ping."
        erreur "Vérifiez que le mediacenter est allumé et joignable sur le réseau."
        return 1
    fi

    if ! export_disponible; then
        erreur "Le serveur répond mais n'exporte pas « $EXPORT »."
        erreur "Contrôlez son /etc/exports et le service nfs-server."
        return 1
    fi

    if [[ ! -d "$POINT_MONTAGE" ]]; then
        info "Création du point de montage « $POINT_MONTAGE »."
        $SUDO mkdir -p -- "$POINT_MONTAGE" || return 1
    fi

    local essai
    for (( essai = 1; essai <= ESSAIS; essai++ )); do
        info "Montage de $SOURCE sur $POINT_MONTAGE (tentative $essai/$ESSAIS)…"
        if $SUDO mount -t "$TYPE_FS" -o "$OPTIONS" -- "$SOURCE" "$POINT_MONTAGE"; then
            info "Montage réussi."
            df -h -- "$POINT_MONTAGE" | tail -n +2
            return 0
        fi
        erreur "Échec de la tentative $essai."
        (( essai < ESSAIS )) && sleep "$DELAI_ESSAI"
    done

    erreur "Impossible de monter le partage après $ESSAIS tentatives."
    return 1
}

demonter() {
    if ! est_monte; then
        info "« $POINT_MONTAGE » n'est pas monté. Rien à faire."
        return 0
    fi

    info "Démontage de « $POINT_MONTAGE »…"
    if $SUDO umount -- "$POINT_MONTAGE"; then
        info "Démonté."
        return 0
    fi

    erreur "Le démontage a échoué : des fichiers sont probablement encore ouverts."
    erreur "Fermez les applications qui utilisent le partage, puis réessayez."
    return 1
}

basculer() {
    if est_monte; then demonter; else monter; fi
}

statut() {
    if est_monte; then
        info "« $POINT_MONTAGE » est monté depuis $SOURCE."
        findmnt --target "$POINT_MONTAGE" 2>/dev/null || true
        df -h -- "$POINT_MONTAGE" | tail -n +2
    else
        info "« $POINT_MONTAGE » n'est pas monté."
        return 1
    fi
}

usage() {
    cat <<EOF
Usage : $(basename "$0") [commande]

Commandes :
  monter    (défaut)   Monte le partage NFS $SOURCE
  demonter             Démonte le partage
  basculer             Démonte s'il est monté, le monte sinon
  statut               Affiche l'état courant
  aide                 Affiche ce message

Partage configuré : $SOURCE  ->  $POINT_MONTAGE  ($TYPE_FS, $OPTIONS)
EOF
}

#-------------------------------- Programme -----------------------------------
if [ $# -ne 1 ]; then
    COMMANDE="monter"
else
    COMMANDE="${1:1}"
fi

case "$COMMANDE" in
#case "${1:1}" in
    "monter"|"mount"|"start")
		monter
		;;
    "demonter|démonter"|"umount"|"unmount"|"stop")
		demonter
		;;
    "basculer"|"toggle")
		basculer
		;;
    "statut"|"status"|"etat"|"état")
		statut
		;;
    "aide"|"-h"|"--help"|"help")
		usage
		;;
    *)
		erreur "Commande inconnue : $1"
        	echo 
		usage
        	exit 2
        	;;
esac
