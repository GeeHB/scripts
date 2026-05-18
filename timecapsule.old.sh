#!/bin/bash
#
#   timecapsule.old.sh
#
#   par Jérôme Henry-Barnaudière
#
#   Version 1.1.1
#
#   le 17/12/2021
#
#   "Mountage" d'un lecteur pour accèder à la Timecapsule
#
#   Remarques : 
#			- Ne fonctionne pas tout le temps !
#
#			- Lorsque le lecteur est monté, l'accès est très lent !
#
#
#   Définition des constantes
#

# Ce script
SCRIPT_NAME="timecapsule.sh"

# Informations sur la Timecapsule
TC_HOST="192.168.1.21"
TC_FOLDER="Data"
TC_ACCOUNT="ouam"
TC_PWD="Rougnou03200"

# Point de "montage"
MOUNT_FOLDER="/home/jhb/shared/timecapsule"

# Mon réseau local (ie. une adresse commence par)
#   Ce motif permet de détecter si le poste est connecté au LAN du CD03
#   Si ce n'est pas le cas, le script s'arrête
#   Par contre, si le poste est connecté au CD03 la maj est effectuée
#
CD03_LAN_ADDR_START_WITH="150.1"

# Un serveur interne à chercher ...
MY_FREEBOX="mafreebox.freebox.fr"

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
echo "$time - Lancement de $SCRIPT_NAME"

user=$( whoami )
if [ $user = "root" ]; then
    echo "Le script ne peut être lancé par root"
else
    echo "Vérification du réseau"
    if ping -c 1 "$MY_FREEBOX" &> /dev/null
    then
        # Oui => on continue
        echo "Recherche de la TimeCapsule"
        
        cmd_string="mount_afp afp://$TC_ACCOUNT:$TC_PWD@$TC_HOST/$TC_FOLDER $MOUNT_FOLDER"
        result=$($cmd_string)
        
        #mount_afp "afp://$TC_ACCOUNT:$TC_PWD@$TC_HOST/$TC_FOLDER $MOUNT_FOLDER"
    else
        echo "Non connecté au réseau domestique"
    fi
fi

time=$( date '+%Y/%m/%d-%H:%M:%S')
echo "$time - Fin des traitements"

# EOF
