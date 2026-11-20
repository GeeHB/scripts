#!/bin/bash

#
#	fortivpn.sh
#
#	Auteur	: JHB
#
#	Version	: 1.0.1 - 3 mai 2020
#
#	Description	: Lancement du VPN
#
#	Attention : le script est lancé par root 
#
#

# Constantes de l'application
#
VPN_SERVER="nomades.cd03.fr"
VPN_USER="henry-barnaudiere.j"

# Le certificat
#VPN_CERT="19c83a0bd44147d81e83db13d1e6762f0fda26078420afa1565aaf6fcb9f33b0"
VPN_CERT="1b9810ab2082c8bb038e794095782e392cc422fe42989473504a28e1e694b514"

# Appel
openfortivpn "$VPN_SERVER" -u "$VPN_USER" --trusted-cert $VPN_CERT
