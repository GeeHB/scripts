#!/bin/bash

#
#   updateOpenLDAP.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 1.2.1
#
#   le 21/09/2022
#
#   Mise à jour de l'Annuaire local à partir d'une source au format LDIF
#
#       Le hash du fichier source est comparé au hash du dernier import. Seul un annuaire différent entrainera la mise à jour
#      
#
#   Appel (par rooot ou sudo) :
#
#               ./updateOpenLDAP.sh [{dest ou}] [-f]
#
#   Remarques :
#
#               Ce script appelle le script updateInternalLDAP.sh -> constante LDAP_SCRIPT
#           
#               Pour obtenir l'ip du poste : ip route get 1.1.1.1
#
#
#   Définition des constantes
#

# Version du script
SCRIPT_NAME="updateOpenLDAP.sh"
SCRIPT_VERSION="1.2.1"

# Binaire pour la génération du fichier LDIF
LDAP2FILE_BIN="/home/jhb/Nextcloud/ldapTools/ldap2File"

# Script à appeler pour effectuer l'import du fichier LDIF
LDAP_SCRIPT="/etc/scripts/updateInternalLDAP.sh"

# Mon réseau local (ie. les des adresses internes qui commencent par)
#   Ce motif permet de détecter si le poste est connecté au LAN du CD03
#   Si ce n'est pas le cas, le script s'arrête
#   Par contre, si le poste est connecté au CD03 la maj est effectuée
#
LAN_ADDR_START_WITH=("150.1" "10.")

# Test ...
#LAN_ADDR_START_WITH="192.168.1"

# "Script" pour la génération du fichier LDIF
LDIF_GEN_SCRIPT="/home/jhb/Nextcloud/ldapTools/CD03/Allier-LDIF.xml"

# Nom du fichier LDIF généré (comme défini dans Allier-LDIF.xml)
#
LDIF_FILE='/home/jhb/Nextcloud/ldapTools/outputs/annuaire.ldif'

# strpos
#   Recherche d'une sous chaine dans une chaine
#
#   $1 : Chaine
#   $2 : sous chaine recherchée
#
#   ret : index ou -1
strpos(){
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

#
#   Corps du script
#

time=$( date '+%Y/%m/%d-%H:%M:%S')
echo "$time - Lancement de $SCRIPT_NAME - Version $SCRIPT_VERSION"

# Toutes les IP du poste
ips=$( hostname -I)

# Le poste est-il connecté au LAN du CD03 ?
pos=-1
for localAddr in ${LAN_ADDR_START_WITH[*]}
        do
            if [ $pos = -1 ]; then
                pos=$(strpos "$ips" "$localAddr")
            fi
        done

if [ $pos = -1 ]; then
    # Non
    echo "Non connecté au LAN du CD03"
    exit 1
fi

echo "Connecté au LAN CD03"
#echo " IP : $ips"

# Le binaire doit exister
if [ -f "$LDAP2FILE_BIN" ]; then
	echo "Binaire d'export au format LDIF : $LDAP2FILE_BIN"

else
    echo "Erreur - Le binaire $LDAP2FILE_BIN n'existe pas"
	exit 1
fi

# Génération du fichier LDIF
$LDAP2FILE_BIN "$LDIF_GEN_SCRIPT"
if [ $? = 0 ]; then
    
    # Pas d'erreur lors de la génération ...
    
    # Import du fichier => Mise à jour du serveur interne
    $LDAP_SCRIPT "$LDIF_FILE"
fi

# Fin
#
time=$( date '+%Y/%m/%d-%H:%M:%S')
echo "$time [$SCRIPT_NAME] - Fin des traitements"

# EOF