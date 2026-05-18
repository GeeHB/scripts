#!/bin/bash

echo "Liste 1"
CHOIX=$(seq 1 6 | gum choose)
clear

echo "Seconde:"
TAILLE=$(gum choose --selected=1024 256 512 1024 2048)
clear

