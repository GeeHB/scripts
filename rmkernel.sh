#!/bin/bash

#       rmkernel.sh
#
#	Auteur	: JHB
#
# 	Date    : 9 sept. 2025
#
#	Description	: Suppression d'un noyau
#
#	Remarques : Le script doit être lancé par root
#
# 	Dépendances : charmbracelet::gum - brew install gum
#

#
# Constantes de l'application
#
APP_NAME="rmkernel.sh"
APP_VERSION="0.3.1"
APP_REL_DATE="9 sept. 2025"
APP_AUTHOR="JHB"

# Dossier(s) pour les kernel
KERNEL_FOLDERS=("/boot" "/boot/loader/entries")

# Dossier pour les librairies
LIB_FOLDER="/usr/lib/modules"

# Fichier utilisé pour générer la liste des kernels installés
# autres que le noyau en-cours d'utilisation
TEMPFILE="/etc/scripts/.kernels.txt"

# Ces kernels ne doivent pas être supprimés
UNDELETABLE_KERNELS=("5.14.11")

# Quitter l'application ...
STR_APP_QUIT="Quitter"

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
#   ret : Nombre de kernels trouvés autres que le noyau en cours
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

  # Ajout de l'option de sortie
  echo $STR_APP_QUIT >> "$TEMPFILE"

  echo $count
}

#
# Script ....
#

echo "$APP_NAME version $APP_VERSION du $APP_REL_DATE par $APP_AUTHOR"

# Le noyau en-cours d'utilisation
THISKERNEL=$(uname -r)

# Lancement interdit à partir du noyau courant ?
found=0
for item in $UNDELETETABLE_KERNELS
do
    if [ $(_strpos "$THISKERNEL" "$item" ) -ne -1 ]; then
        # Trouvé
        found=1
    fi
done
if [ $found -ne 0 ]; then
  _exit "Ce script ne peut pas être appelé à partir du noyau '$THISKERNEL'" 3
fi

_displayVariable "Kernel en cours" $THISKERNEL

# Lancé par root !!!
if [ $(id -u) -ne 0 ]; then
  _exit "Le script doit être lancé par root" 1
fi

while true; do
	# Liste des kernels installés
	if [ $(_kernels $THISKERNEL $TEMPFILE) -eq 0 ]; then
	  _exit "Pas de noyau à supprimer" 1
	fi

	# Choix du noyau à supprimer
	KERNEL=$(gum choose  < "$TEMPFILE" )

	# Sortie de l'application ?'
	if [ $(_strpos "$KERNEL" "$STR_APP_QUIT") = 0 ]; then
	   _exit "Terminé" 1
	else
    	if [ ${#KERNEL} -gt 0 ]; then
    	    gum confirm --affirmative="Oui" --negative="Annuler" "Suppression de $KERNEL" || _exit "Annulé" 1
    	else
    	    _exit "Annulé" 2
        fi
	fi

	# On continue
	_displayVariable "Suppression" $KERNEL

	pos=$(_strpos $KERNEL "-")
	if [ $pos -eq -1 ]; then
	  _exit "Erreur dans le nom du kernel" 2
	fi

	# Desinstallation des paquets du kernel
	gum spin -s line --title "Retrait des paquets du kernel" -- dnf remove $KERNEL -y
	
	# Autres paquets liés au kernel (kernel-devel... kernel-core ... etc)
	LEFT=$(echo $KERNEL| cut -d'.' -f 1)
	RIGHT=$(echo $KERNEL|cut -d'.' -f 2)
	KERNEL_OTHER="${LEFT}-*-${RIGHT}"
	gum spin -s line --title "Retrait des paquets associés au kernel" -- dnf remove $KERNEL_OTHER -y
	
	if [ $? -eq 0 ];
	then
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

		echo $"{{ Bold \"$KERNELVER a été désinstallé avec succès\"}}" \ | gum format -t template
		echo $'\n'
	else
		_exit "Erreur lors de la suppression de $KERNEL" 2	
	fi	
done

# EOF
