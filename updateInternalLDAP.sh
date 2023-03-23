#!/bin/bash

#
#   updateInternalLDAP.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 1.1.7
#
#   le 10/10/2022
#
#   Mise à jour de l'Annuaire local à partir d'une source au format LDIF
#
#       Le hash du fichier source est comparé au hash du dernier import. Seul un annuaire différent entrainera la mise à jour
#      
#
#   Appel (par rooot ou sudo) :
#
#               ./updateInternalLDAP.sh {source file} [{dest ou}] [-f]
#
#   Remarques :
#                   slapadd -clv  {file} est utilisé pour l'insertion en mode verbose (-v)
#

#
#
#   Définition des constantes
#

# Version du script
SCRIPT_NAME="updateInternalLDAP.sh"
SCRIPT_VERSION="1.1.7"

# Ligne de commandes
CMD_FORCE="-f"

#
# Paramètres LDAP
#

# OU contenant les éléments à ajouter ou supprimer
#   valeur par défaut. Peut être fournie en ligne de commande (2eme paramètre)
#
WORKING_OU="ou=users,dc=allier,dc=fr"

# Compte d'admin LDAP (aie !!!)
LDAP_MANAGER_DN='cn=manager,dc=allier,dc=fr'
LDAP_MANAGER_PWD='zita'

#
# Dossiers locaux
#

# Dossier de travail
WORK_FOLDER='/etc/scripts'

# ou se trouve slapcat ety les outils LDAP ?
LDAPUTILS_FOLDER='/usr/sbin'

# ou se trouvent les outils shaxxx
SHAUTILS_FOLDER='/usr/bin'

# Dossier pour la BD ldap
LDAP_LIB_FOLDER="/var/lib/ldap"

#
# Nom des fichiers
#

# Fichier de hash
HASH_FILE='.hashCD03LDIF.jhb'
TEMP_HASH_FILE='.hashCD03Temp.jhb'

# Fichier temporaire pour la création de l'ou
TEMP_OU_FILE=".ou.ldif"

#
#   Quelques fonctions ...
#

# usage
#   Affichage de l'usage d'appel du script
#
#   pas de paramètres
#
#   pas de retour
usage(){
    echo ''
    echo "$SCRIPT_NAME {ldifFile} [{ouDN}] [-f]"
    echo "    ldifFile : nom du fichier à importer"
    echo "    ouDN : DN de l'ou à vider puis remplir à partir du fichier d'import - Facultatif"
    echo "    -f : Forcer la mise à jour - Facultatif"
}

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

# hashFromFile
#   Extraction du fichier de hash
#
#   $1 : Fichier source
#
#   ret : hash du fichier ou "" en cas d'erreur
hashFromFile(){
    if [ -n "$1" ]; then 
        echo $(cut -d' ' -f1 "$1")
    else
        echo ""
    fi
}

#
#   Corps du script
#

time=$( date '+%Y/%m/%d-%H:%M:%S')
echo "$time - Lancement de $SCRIPT_NAME - Version $SCRIPT_VERSION"

# Gestion des paramètres de la ligne de commandes
#
if [ $# = 0 ]; then
    usage
    exit 1
fi

# Le premier paramètre est le nom du fichier (qui doit exister)
srcFile=$1

# Le 2nd paramètre est le DN de l'ou ou "-f"
force="no"
ou=$WORKING_OU
if [ $# = 2 ]; then
    if [ $2 = $CMD_FORCE ]; then
        force=$CMD_FORCE    
    else
        ou=$2
    fi
fi

ouShort=${ou:3}
pos=$(strpos "$ouShort" ",")
if [ $pos = -1 ]; then
    echo "La valeur $ou est invalide"
    exit 1
fi
ouShort=${ouShort:0:$pos}

# Forcer ?
if [ $# = 3 ]; then
    ou=$2
    force=$3
fi

# Le fichier source existe t'il ?
if [ -f "$srcFile" ]; then
    # Juste pour éviter de tester l'absence de fichier ...
    echo " "    
else
    echo "Le fichier source '$srcFile' n'existe pas"
    exit 1
fi

echo "    - source : $srcFile"
echo "    - ou destination : $ou"
echo "    - ou : $ouShort"

# Fichiers de hash
hashFile=$WORK_FOLDER'/'$HASH_FILE
hashTemp=$WORK_FOLDER'/'$TEMP_HASH_FILE

if [ $force = $CMD_FORCE ]; then
    # Suppression du hash caché
    if [ -f "$hashFile" ]; then
        echo "    - Mode forcé"
        rm "$hashFile"
    fi
fi

# Génération du hash du fichier à importer
$SHAUTILS_FOLDER/sha256sum "$srcFile" > "$hashTemp"
newHash=$(hashFromFile "$hashTemp")

if [ ${#newHash} = 0 ]; then
    echo "Erreur dans le calcul du hash de '$srcFile'"
    exit 1
fi

#echo "Hash du fichier source : $newHash"

# Y a t'il déja un fichier de hash ?
if [ -f "$hashFile" ]; then
	#echo "Vérification de l'ancien fichier de Hash"
	oldHash=$(hashFromFile "$hashFile")
else
    # Pas de fichier => forcément bon ...
    echo "Pas d'ancien fichier de hash"
	oldHash="0xAA"
fi

# Le fichier proposé est différent du dernier fichier importé
if [ "$newHash" != "$oldHash" ]; then
	echo "Nouveaux mouvments détectés"

    # Suppression de l'ancien hash ...
    if [ -f "$hashFile" ]; then
        echo "    - Suppression de '$hashFile'"
        rm "$hashFile"
    fi

    # ... et remplacement par le nouveau
    echo "    - Renommage de '$hashTemp' en '$hashFile'"
    mv $hashTemp $hashFile
    
    # Application des changements
    #
    echo "Gestion du contenu LDAP"
    echo "    - Suppression de l'ou '$ou'"
    ldapdelete -D $LDAP_MANAGER_DN -w $LDAP_MANAGER_PWD -r "$ou"

    # Arrêt
    echo "    - Arrêt de slapd"
    systemctl stop slapd

    # Création de l'ou
    ouFile=$WORK_FOLDER'/'$TEMP_OU_FILE
    echo "dn: $ou" > "$ouFile"
    echo "objectClass: organizationalUnit" >> "$ouFile"
    echo "objectClass: top" >> "$ouFile"
    echo "ou: $ouShort" >> "$ouFile"

    echo "    - Création de l'ou vide '$ou'"
    $LDAPUTILS_FOLDER/slapadd -cl "$ouFile"
    rm "$ouFile"

    echo "    - Import du fichier source"
    $LDAPUTILS_FOLDER/slapadd -cl "$srcFile"
    #$LDAPUTILS_FOLDER/slapadd -cvl "$srcFile"

    echo "    - Changement des droits sur '$LDAP_LIB_FOLDER'"
    chown -R ldap:ldap "$LDAP_LIB_FOLDER"
    
    # Lancement du service
    echo "    - Lancement de slapd"
    systemctl start slapd
else
    echo "Pas de nouveaux mouvements. Il n'y aura pas d'import"

    # Suppression du hash temporaire
    rm "$hashTemp"

    # Code retour particulier ...
    exit 3
fi

# Fin
#
time=$( date '+%Y/%m/%d-%H:%M:%S')
echo $time' - Fin des traitements'

# EOF