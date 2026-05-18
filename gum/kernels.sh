#!/bin/bash

# kernels.sh
#
#   Choix d'un noyau (autre que celui en cours) dans la liste des noyaux présents sur le poste
#
#   Accessoirement test de l'utilitaire GUM
#

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

# Affichage d'une variable et de sa valeur
displayVariable() {
  echo "$(gum style --foreground 99 "$1:")" "$2"
}

# Ma sortie
myExit(){
  echo "$(gum style --foreground 99 "$1")"
  exit $2
}

#
# Script ....
#

clear 
gum style \
  --foreground 99 \
  --border double \
  --border-foreground 99 \
  --padding "1 2" \
  --margin 1 "remove an installed kernel"

sleep 1

# Le fichier temporaire
TEMPFILE="./.kernels.txt"
if [ -e $TEMPFILE ]; then
    # Le fichier ne doit pas exister
    rm $TEMPFILE
fi

# Liste des kernels installés
LIST=$(rpm -q kernel)

# Le noyau en-cours d'utilisation
CURRENT=$(uname -r)
displayVariable "Kernel en cours" $CURRENT

# Recherche du kernel actuel dans la liste
count=0
for item in $LIST
do
        if [ $(strpos "$item" "$CURRENT") = -1 ]; then
            # Pas lui => ajout
            echo $item >> "$TEMPFILE"
            count=$((count+1))
        fi
done

# Affichage de la liste sans la valeur (si elle était présente)
KERNEL=$(gum choose  < "$TEMPFILE" )

# Plus besoin du fichier
if [ -e $TEMPFILE ]; then
    rm $TEMPFILE
fi

# Noyau à supprimer
if [ ${#KERNEL} -gt 0 ]; then
    gum confirm --affirmative="Oui" --negative="Annuler" "Suppression de $KERNEL" || myExit "Annulé" 1
else
    myExit "Annulé" 1
fi

# On continue
displayVariable "Suppression" $KERNEL

# EOF