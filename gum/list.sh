#!/bin/bash

# Le fichier temporaire
TEMPFILE="./.list.txt"
if [ -e $TEMPFILE ]; then
    rm $TEMPFILE
fi

# Ma liste
LIST=$(seq 1 6)

# Recherche de la valeur "2"
count=0
index=-1
for item in $LIST
do
        if [ $item = 2 ]; then
            index=$count
        else
            echo $item >> "$TEMPFILE"
        fi

        # Ligne suivante
        count=$((count+1))
done

# Affichage de la liste sans la valeur (si elle était présente)
echo "Seconde:"
TAILLE=$(gum choose < "$TEMPFILE")

# Plus besoin du fichier
if [ -e $TEMPFILE ]; then
    rm $TEMPFILE
fi

#clear