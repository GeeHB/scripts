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
#VPN_CERT="1c208ce3c636b6d5c099d65b14bab723f3301b1bb70b0b2e5b0d64a90c804405"
VPN_CERT="b895547d5934872cbd1c2f95fcfcc55d655e7a4ff205a78fde303a68ea86b82d"

# Appel
openfortivpn "$VPN_SERVER" -u "$VPN_USER" --trusted-cert $VPN_CERT
