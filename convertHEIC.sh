#!/bin/bash

#       convertHEIC.sh
#
#	Auteur	: JHB
#
# 	Date    : 18 mai 2026
#
#	Description	: Conversion de tous les fichiers HEIC d'un dossier au format jpeg
#
#	Commande : ./convertHEIC.sh <source dir>
#

# Vérifier si le répertoire source est fourni en argument
if [ -z "$1" ]; then
    echo "Utilisation : ./convertHEIC.sh <répertoire_source>"
    exit 1
fi

SOURCE_DIR="$1"

# Vérifier si le répertoire existe
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Erreur : Le répertoire '$SOURCE_DIR' n'existe pas."
    exit 1
fi

# Convertir tous les fichiers .heic (insensible à la casse) en jpeg
# -format jpeg : définit le format de sortie
# -path : spécifie le répertoire de destination
# -path doit être relatif ou absolu
cd "$SOURCE_DIR" || exit

fichiers=0

for file in *.HEIC; do
    # Extraire le nom de base sans l'extension
    basename="${file%.*}"

    # Convertir l'image
    heif-convert -q 90 --quiet "$file" "${SOURCE_DIR}/${basename}.jpg"

    # Le fichier destination a été crée avec succès
    if [ -s "${SOURCE_DIR}/${basename}.jpg" ]; then
        rm "$file"
        echo "Converti : $file -> ${SOURCE_DIR}/${basename}.jpg"
        ((fichiers++))
    fi
done

echo "Conversion terminée. $fichiers fichier(s) converti(s) dans $OUTPUT_DIR"

# EOF
