#!/bin/bash

#
#	myIP.sh
#
#	Auteur	: JHB
#
#	Version	: 1.1 - 5 avril 2019
#
#	Description	: Affichage de l'IP "interne" du poste, si elle existe
#				  Testé sur Fedora 29/Gnome 3
#

#
# Constantes de l'application
#

# Classe des IP profesionnelles
PRO_IP="150."


# Traitements ...
#
echo "myIP - Lancement des traitements"

# Adresse IP du poste
#
# myIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

# L'adresse IPV4 est la deuxième "valeur" affichée
myIP=$(ifconfig | grep "inet $PRO_IP" | awk '{print $2}' | cut -f 2 )
myIPLen=${#myIP}

# Adresse professionnelle ?
if [ "$myIPLen" -gt 0 ]; then
	echo "Adresse IP interne : $myIP"
else
	echo "Pas sur le réseau interne"
fi

echo "myIP - Fin des traitements"
