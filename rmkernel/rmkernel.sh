#!/bin/bash

#             rmkernel.sh
#
#	Auteur	: JHB
#
# Date    : 23 mars 2023
#
#	Description	: Suppression d'un noyau
#
#	Remarques : Le script doit être lancé par root 
#
# Dépendances : charmbracelet::gum - brew install gum
#

#
# Constantes de l'application
#
APP_NAME="rmkernel.sh"
APP_VERSION="0.1.1"

# Dossier(s) pour les kernel
KERNEL_FOLDERS=("/boot" "/boot/loader/entries")

# Dossier pour les librairies
LIB_FOLDER="/usr/lib/modules"

# Fichier utilisé pour générer la liste des kernels installés
# autres que le noyau en-cours d'utilisation
TEMPFILE="./.kernels.txt"

#
# Fonctions à usage interne
#

#   Recherche d'une sous chaine dans une chaine
#   syntaxe // stdlib::strpos
#
#   $1 : Chaine
#   $2 : sous chaine recherchée
#
#   ret : index ou -1 (si non trouvé)
_strpos(){
  x="${1%%$2*}"
  [[ "$x" = "$1" ]] && echo -1 || echo "${#x}"
}

# Affichage d'une variable et de sa valeur
_displayVariable() {
  echo "$(gum style --foreground 99 "$1:")" "$2"
}

# Fin du script, avec message
_exit(){
  echo "$(gum style --foreground 212 "$1")"
  exit $2
}

# Liste des kernels (autre que le kernel courant)
#
#   $1 : Nom du kernel courant
#   $2 : Nom du fichier qui contiendra la liste
#
#   ret : Nombre de kernels trouvés
_kernels(){
  # Suppression du fichier temporaire
  if [ -e $2 ]; then
      rm $2
  fi

  # Liste des kernels installés
  LIST=$(rpm -q kernel)

  # Recherche du kernel actuel dans la liste
  count=0
  for item in $LIST
  do
      if [ $(_strpos "$item" "$1") = -1 ]; then
          # Pas lui => ajout
          echo $item >> "$TEMPFILE"
          count=$((count+1))
      fi
  done

  echo $count
}

#
# Script ....
#

echo "$APP_NAME version $APP_VERSION"

# Lancé par root !!!
if [ $(id -u) -ne 0 ]; then
  _exit "Le script doit être lancé par root" 1
fi

# Le noyau en-cours d'utilisation
CURRENT=$(uname -r)
_displayVariable "Kernel en cours" $CURRENT

# Liste des kernels installés
if [ $(_kernels $CURRENT $TEMPFILE) -eq 0 ]; then
  _exit "Pas de noyau à supprimer" 1
fi

# Choix du noyau à supprimer
KERNEL=$(gum choose  < "$TEMPFILE" )
if [ ${#KERNEL} -gt 0 ]; then
    gum confirm --affirmative="Oui" --negative="Annuler" "Suppression de $KERNEL" || _exit "Annulé" 1
else
    _exit "Annulé" 1
fi

# On continue
_displayVariable "Suppression" $KERNEL

pos=$(_strpos $KERNEL "-")
if [ $pos -eq -1 ]; then
  _exit "Erreur dans le nom du kernel" 2
fi

# Desinstallation des paquets
gum spin -s line --title "Retrait des paquets" -- dnf remove $KERNEL -y

# Nom court
KERNELVER=${KERNEL#*-}

# Suppression des fichiers "kernel"
#
folders=${#KERNEL_FOLDERS[@]}
if [ $folders -gt 0 ]
then
    index=0
    while [ $index -lt $folders ]; do
      folder=${KERNEL_FOLDERS[$index]}

      if [ -d $folder ]; then
        cd $folder
        rm -rf *-$KERNELVER*
      fi
      index=$((index+1))
    done
fi
    
## Suppression des librairies
cd $LIB_FOLDER
rm -rf $KERNELVER

# Terminé ...
echo "{{ Bold \"$KERNEL désinstallé avec succès\"}}" \ | gum format -t template

gum confirm --affirmative="Reboot" --negative="Non" "Redémarrer le poste" && reboot 

# EOF