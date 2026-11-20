#!/bin/bash

# Ajouter une gestion des erreurs : 2>/dev/null


EXTENT="ARW"
FOLDER="jpeg"

# On crée le dossier destination
outFolder="./$FOLDER"
if [ ! -d "$outFolder" ]; then
    echo "Création du dossier $outFolder"
    mkdir "$outFolder"
fi


# Vérifier qu'il y a des fichiers
files=(*.$EXTENT)
if [ ${#files[@]} -eq 0 ]; then
    echo "Aucun fichier .$EXTENT trouvé."
else
    # Boucler sur chaque fichier
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            out="./$FOLDER/${f%.$EXTENT}.jpg"
	    #echo "$out"
            #dcraw -f -h -T -q 3 -w "$f" "$out"
            dcraw -c -h -q 3 -w "$f" | convert - -quality 95 "$out"
        fi
    done
fi

