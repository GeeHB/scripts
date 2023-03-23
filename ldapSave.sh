#!/bin/bash

#
#   ldapSave.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 2.4.2
#
#   le 18/04/2019
#
#   Sauvegarde de l'annuaire LDAP au format LDIF
#
#       L'annuaire est exporté puis comparé à la dernière version stockée.
#       La sauvegarde ne sera conservée puis copiée dans le cloud que si elle différente
#       de la précédente. 
#
#       Le script conserve un nombre variable (MAXFILES) de sauvegarde (local et/ou cloud)
#       les plus anciennes étant automatiquement supprimées
#
#	Lorsque REMOTEFOLDER est renseigné, une copie est effectuée en SSH à destination du serveur
#
#
#   Définition des constantes
#

# Prefixe pour le nom du fichier
PREFIX='jhb-'

# Nombre de fichiers différents à conserver
MAXFILES=5

# Dossier destination
DESTFOLDER='/etc/scripts/backup'

# Dossier(s) pour la sauvegarde sur le cloud
CLOUDFOLDERS=('/home/jhb/Dropbox/archives/ldap' '/home/jhb/Nextcloud/archives/ldap')

# Copie en ssh sur un autre serveur
REMOTESERVER=''
REMOTELOGIN='jhb'
REMOTEFOLDER='/home/jhb/Dropbox/SMH/Archives/Organigramme'

# ou se trouve slapcat ?
LDAPUTILSFOLDER='/usr/sbin'

# ou se trouvent les outils shaxxx
SHAUTILSFOLDER='/usr/bin'


#
#   Quelques fonctions
#

# Nettoyage d'un dossier
#   $1 = chemin complet du dossier
#   $2 = extension à supprimer / vérifier
#   $3 = prefixe (facultatif)
cleanFolder(){
    listFile=$1'/list.out'

    #echo "Recherche de : "$3'*.'$2
    
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

        index=0
        while read file; do
            if [ "$index" -lt "$count" ]
            then
                echo '    '$file
                rm $file
            fi
            index=$((index+1))
        done < $listFile
    else
        #echo '    Pas de fichier à supprimer dans '$1' ('$count' fichiers dans le dossier)'
        echo '    Pas de fichier à supprimer dans '$1
    fi

    rm $listFile    
}

#
#   Corps du script
#

# Fichier de hash
hashFile=$DESTFOLDER'/hashLDIF.txt'
hashTemp=$DESTFOLDER'/hashLDIFTemp.txt'

time=$( date '+%Y/%m/%d-%H:%M:%S')
echo $time'-Lancement de ldapSave.sh'

# Nom du fichier à générer
shortName=$PREFIX$( date '+%Y%m%d-%H%M' )'.ldif'
file=$DESTFOLDER'/'$shortName

# Nombre de dossier destination dans le cloud
cloudFolders=${#CLOUDFOLDERS[@]}
echo '    '$cloudFolders' dossier(s) sur le cloud'

# Sauvegarde de l'annuaire
#

# si le fichier du jour (à la minute près) existe, il n'y a rien à faire
if [ -f $file ]
then
    echo '    Le fichier '$file' existe déja'
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo $time'-Fin des traitements'
    exit 1
fi

# Génération du fichier du jour ...
echo '    Génération de '$file
$LDAPUTILSFOLDER/slapcat -l $file
#fileSize=$(stat -c%s "$file")
if [ ! -f $file ]
then
    echo '    Impossible de générer le fichier LDIF'
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo $time'-Fin des traitements'
    exit 1
fi
#echo '    Fichier LDIF généré - '$fileSize' octets'

# ... et de son hash
$SHAUTILSFOLDER/sha256sum $file > $hashTemp
newHash=$(cut -d' ' -f1 $hashTemp)
echo '    Hash calculé :'$newHash

# y a t'il déja un fichier de hash ?
if [ -f $hashFile ]
then
	echo "    Vérification de l'ancien fichier de Hash"
	oldHash=$(cut -d' ' -f1 $hashFile)
else
    # le fichier est forcément bon ...
    # on conserve son hash
	echo "    Pas d'autre fichier dans le dossier"
	oldHash=newHash
fi

# Le fichier du jour est différent du dernier fichier de hash
if [ "$newHash" != "$oldHash" ]
then
	echo '    Les fichiers LDIF sont différents'

    # suppression de l'ancien hash ...
    if [ -f $hashFile ]
    then
        echo '    Suppression de '$hashFile
        rm $hashFile
    fi

    # ... et remplacement par le nouveau
    echo '    Renommage de '$hashTemp 'en '$hashFile
    mv $hashTemp $hashFile

    # Copie(s) dans le cloud
    if [ $cloudFolders -gt 0 ]
    then
        index=0
        while [ $index -lt $cloudFolders ]; do
            folder=${CLOUDFOLDERS[$index]}
            echo '    Copie vers '$folder'/'$shortName
            cp $file $folder'/'$shortName  

            # dossier suivant
            index=$((index+1))
        done
    fi

    # ... enfin copie du fichier sur le serveur distant
    if [ ${#REMOTESERVER} -gt 0 ] 
    then
        scp $file $REMOTELOGIN'@'$REMOTESERVER':'$REMOTEFOLDER
        echo '    Transfert par SSH sur le serveur distant '$REMOTESERVER
    fi
else
    # Aucune modification => je supprime les fichiers du jour
	echo '    Le fichier LDIF est identique au précédent'
    rm $file
    rm $hashTemp
fi

#
# Suppression des anciens fichiers
#

# en local ...
cleanFolder $DESTFOLDER 'ldif' $PREFIX

# ... puis sur le cloud
if [ $cloudFolders -gt 0 ]
then
    index=0
    while [ $index -lt $cloudFolders ]; do
        cleanFolder ${CLOUDFOLDERS[$index]} 'ldif' $PREFIX
        index=$((index+1))
    done
fi


# Fin
#
time=$( date '+%Y/%m/%d-%H:%M:%S')
echo $time'-Fin des traitements'

# EOF
