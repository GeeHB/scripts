#!/bin/bash
#
#   timecapsule.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version :   2.0.2
#
#   Date    :   08/01/2022
#
#   Description :   "Mountage" d'un lecteur pour accèder à la Timecapsule
#
#   Remarques : 
#
#           Basé sur 'tc.sh', qui fonctionne avec un "vieux" kernel, 
#           et 'timecapsule.old.sh' qui est lent et ne fonctionne pas tout le temps ...
#

#
#   Définition des constantes
#

# Ce script
#SCRIPT_NAME="timecapsule.sh"

# Informations sur la Timecapsule
TC_HOST="192.168.1.21"
TC_FOLDER="Data"
#TC_ACCOUNT="ouam"               # Ne sert absolument à rien
TC_PWD="Rougnou03200"

# Point de "montage"
MOUNTED_FOLDER="/home/jhb/shared/timecapsule/"

# Ce kernel permet de "mounter"  le lecteur (les autres non !)
VALID_KERNEL="5.14.11"

#
#   Corps du script
#

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

# Kernel valide ?
k=$(uname -r)
pos=$(strpos "$k" "$VALID_KERNEL")
if [ $pos = 0 ]; then
    # Tentative de création du lecteur
    cmdParams="//$TC_HOST/$TC_FOLDER $MOUNTED_FOLDER -o password=$TC_PWD,sec=ntlm,uid=1000,vers=1.0"
    #echo $cmdParams
    mount.cifs $cmdParams
else
    # Non !!!!
    echo "Cette version du kernel - $k - ne permet pas une connexion en SMB1.0"
fi

# EOS
