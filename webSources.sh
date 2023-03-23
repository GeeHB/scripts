#!/bin/bash

#
#   webSources.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 1.1.4
#
#   le 20/12/2019
#
#   Sauvegarde d'une ou de plusieurs arborescence(s) web dans un fichier au format tar.gz
#
#       La sauvegarde ne sera conservée puis copiée dans le cloud que si elle différente
#       de la précédente. 
#
#       Le script conserve un nombre variable (MAXFILES) de sauvegarde (local et/ou cloud)
#       les plus anciennes étant automatiquement supprimées
#
#	Lorsque REMOTEFOLDER est renseigné, une copie est effectuée en SSH à destination du serveur
#
#
#   La commande executée est : tar --exclude='./organigramme/js/datas' -zcf backup.tar.gz ./organigramme
#

#
#   TODO
#
#   1 - Liste des dossiers à exclure
#
#   2 - Fournir juste le nom du dossier à sauvegarder ...
#
#   3 - Mode silencieux ...


#   Définition des constantes
#

# Le dossier à compresser est dans :
BASEFOLDER='/var/www/html'

# Le nom des dossiers à compresser
SOURCEFOLDERS=('organigramme' 'squid') 
#SOURCEFOLDER='organigramme'

# Dossier à exclure (en partant du dossier sauvegardé)
#EXCLUDEFOLDERS=('./organigramme/js/datas')
EXCLUDEFOLDER='./organigramme/js/datas'

# Prefixe pour le nom du fichier
PREFIX='jhb-'

# Nombre de fichiers différents à conserver
MAXFILES=5

# Dossier destination
DESTFOLDER='/etc/scripts/backup'

# Dossier(s) pour la sauvegarde sur le cloud
CLOUDFOLDERS=('/home/jhb/Dropbox/Archives/web' '/home/jhb/Nextcloud/archives/web')

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

# Taille du précédent fichier
zipFileSize=$DESTFOLDER'/fileSizeWeb.txt'
zipFileSizeTemp=$DESTFOLDER'/fileSizeWebTemp.txt'

time=$( date '+%Y/%m/%d-%H:%M:%S')
echo $time" webSources - Lancement de l'application"

# Nom du fichier à générer
shortName=$PREFIX$( date '+%Y%m%d-%H%M' )'.tar.gz'
file=$DESTFOLDER'/'$shortName

# Nombre de dossier destination dans le cloud
cloudFolders=${#CLOUDFOLDERS[@]}
echo '    '$cloudFolders' dossier(s) sur le cloud'

# Sauvegarde des fichiers
#

# si le fichier du jour (à la minute près) existe, il n'y a rien à faire
if [ -f $file ]
then
    echo '    Le fichier '$file' existe déja'
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo $time' webSources - Fin des traitements'
    exit 1
fi

# Au moins au sous-dossier à sauvegarder
sourceFolders=${#SOURCEFOLDERS[@]}
if [ $sourceFolders -eq 0 ]
then
    echo '    Pas de dossier à compresser'
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo $time' webSources - Fin des traitements'
    exit 1
fi

# Génération du fichier du jour ...
echo '    Génération de '$file

# Dossier(s) à include
folders=''
index=0
while [ $index -lt $sourceFolders ]; do
    folder=${SOURCEFOLDERS[$index]}
    # folders+=folder
    folders="${folders} $folder"

    # dossier suivant
    index=$((index+1))
done

# C'est parti !
cd $BASEFOLDER
tar --exclude=$EXCLUDEFOLDER -zcf $file $folders
fileSize=$(stat -c%s "$file")
stat -c%s "$file" > $zipFileSizeTemp
if [ ! -f $file ]
then
    echo "    Impossible de générer le fichier d'archive"
    time=$( date '+%Y/%m/%d-%H:%M:%S')
    echo $time' webSources - Fin des traitements'
    exit 1
fi

# y a t'il déja un fichier ?
if [ -f $zipFileSize ]
then
	echo "    Vérification de l'ancien fichier"
	oldFileSize=$(cut -d' ' -f1 $zipFileSize)
else
    # le fichier est forcément bon ...
    # on conserve le conserve
	echo "    Pas d'autre fichier dans le dossier"
	oldFileSize=0
fi

# Le fichier du jour est différent du dernier fichier
if [ "$fileSize" != "$oldFileSize" ]
then
	echo "    Les fichiers d'archive sont différents"

    # suppression de l'ancien
    if [ -f $zipFileSize ]
    then
        echo '    Suppression de '$zipFileSize
        rm $zipFileSize
    fi

    # ... et remplacement par le nouveau
    echo '    Renommage de '$zipFileSizeTemp 'en '$zipFileSize
    mv $zipFileSizeTemp $zipFileSize

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
	echo "    Le fichier d'archive est identique au précédent"
    rm $file
    rm $zipFileSizeTemp
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
echo $time' webSources - Fin des traitements'

# EOF