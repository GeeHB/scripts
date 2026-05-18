#!/bin/bash

#
#   updateOwnLDAPServer.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 1.0.6
#
#   le 11/01/2023
#
#   Mise à jour de l'Annuaire local à partir d'une source au format LDIF
#
#       Le hash du fichier source est comparé au hash du dernier import. Seul un annuaire différent entrainera la mise à jour
#      
#
#   Appel (par rooot ou sudo) :
#
#               ./updateOwndLDAPSer.sh [{dest ou}] [-f]
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
SCRIPT_NAME="updateOwnLDAPServer.sh"
SCRIPT_VERSION="1.0.6"

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

# Prefixe pour le nom du fichier si sauvegardé dans le cloud
PREFIX='own-'

# Nombre de fichiers différents à conserver par dossier
MAXFILES=3

# Dossier(s) pour la sauvegarde sur le cloud
#CLOUDFOLDERS=('/home/jhb/Dropbox/Archives/LDAP' '/home/jhb/Nextcloud/documents/3-projets/Annuaire/Archives/LDIF')
CLOUDFOLDERS=('/home/jhb/Nextcloud/documents/3-projets/Annuaire/Archives/LDIF')

#
#   Quelques fonctions à usage interne
#

# cleanFolder()
# Nettoyage d'un dossier
#   $1 = chemin complet du dossier
#   $2 = extension à supprimer / vérifier
#   $3 = prefixe (facultatif)
cleanFolder(){
    listFile=$1'/list.out'

    # liste des fichiers à analyser
    find $1 -type f -name $3'*.'$2 | sort > $listFile

    # #?
    count=0
    while read file; do
        count=$((count+1))
    done < $listFile

    # Des fichiers surnuméraires ?
    if [ "$count" -gt $MAXFILES ]
    then
        # Nombre de fichier à supprimer
        count=$((count-MAXFILES))    
        echo '    '$count' ancien(s) fichier(s) à supprimer'
$
        fileIndex=0
        while read file; do
            if [ "$fileIndex" -lt "$count" ]
            then
                echo '    '$file
                rm $file
            fi
            fileIndex=$((fileIndex+1))
        done < $listFile
    else
        echo '    Pas de fichier à supprimer dans '$1
    fi

    rm $listFile    
}

# strpos
#   Recherche d'une sous chaine dans une chaine
#   syntaxe // stdlib::strpos
#
#   $1 : Chaine
#   $2 : sous chaine recherchée
#
#   ret : index ou -1 (si non trouvé)
strpos(){
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

# myecho
#   Affichage en mode console avec date et heure
#
#   $1 : chaine à afficher
#
#   ret : aucun
myecho(){
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo "$time - $1"    
}

#
#   Corps du script
#

myecho "Lancement de $SCRIPT_NAME - Version $SCRIPT_VERSION"

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
    myecho "Non connecté au LAN du CD03"
    exit 1
fi

myecho "Connecté au LAN CD03"
#myecho " IP : $ips"

# Le binaire doit exister
if [ -f "$LDAP2FILE_BIN" ]; then
	myecho "Binaire d'export au format LDIF : $LDAP2FILE_BIN"

else
    myecho "Erreur - Le binaire $LDAP2FILE_BIN n'existe pas"
	exit 1
fi

# Génération du fichier LDIF
$LDAP2FILE_BIN "$LDIF_GEN_SCRIPT"

# Récupération du code retour
retCode=$?

if [ $retCode -eq 0 ]; then
    
    # Pas d'erreur lors de la génération ...
    
    # Import du fichier => Mise à jour du serveur interne
    $LDAP_SCRIPT "$LDIF_FILE"

    # Récupération du code retour
    retCode=$?

    if [ $retCode -eq 0 ]; then
    
        # Nombre de dossier destination dans le cloud
        cloudFolders=${#CLOUDFOLDERS[@]}
        myecho '    '$cloudFolders' dossier(s) sur le cloud'

        # Copie dans le cloud et suppression des fichiers surnuméraires
        if [ $cloudFolders -gt 0 ]
        then
            # Nom du fichier à générer
            shortName=$PREFIX$( date '+%Y%m%d-%H%M' )'.ldif'

            index=0
            while [ $index -lt $cloudFolders ]; do
                folder=${CLOUDFOLDERS[$index]}
                myecho '    Copie vers '$folder'/'$shortName
                
                # Copie ...
                cp "$LDIF_FILE" "$folder/$shortName"

                # Suppression(s)  
                cleanFolder ${CLOUDFOLDERS[$index]} 'ldif' $PREFIX
                
                # Dossier suivant
                index=$((index+1))
            done
        fi
    fi
fi

# Fin
#
myecho "$time [$SCRIPT_NAME] - Fin des traitements"

# EOF