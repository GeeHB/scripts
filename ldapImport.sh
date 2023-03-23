#! /bin/bash

manager='cn=manager,dc=allier,dc=fr'
password='\nY08S;2'
file='/etc/scripts/import/annuaire.ldif'

time=$( date '+%Y/%m/%d-%H:%M:%S')

if [ -f $file ]
then
    echo $time' - Lancement de ldapImport.sh'

    printf "######################################################\n"
    printf "# Suppression de l'OU users                          #\n"
    printf "######################################################\n"
    sudo ldapdelete -D $manager -w $password -r "ou=users,dc=allier,dc=fr"
    
    printf "######################################################\n"
    printf "# Arrêt du service OpenLDAP                          #\n"
    printf "######################################################\n"
    sudo systemctl stop slapd

    # Import du fichier vierge et du fichier provenant d'Epicea
    printf "######################################################\n"
    printf "# Ré-injection des données de l'OpenLDAP de PROD     #\n"
    printf "######################################################\n"
    sudo slapadd -v -c -l /home/mp/import\ vierge.ldif
    sudo slapadd -v -c -l $file

    # Suppression du fichier annuaire
    sudo rm $file

    # Attribution des droits à l'utilisateur LDAP
    printf "######################################################\n"
    printf "# Attribution des droits à l'utilisateur LDAP        #\n"
    printf "######################################################\n"
    sudo chown -R ldap:ldap /var/lib/ldap
    sudo systemctl start slapd

    printf "#########################################################################\n"
    printf "# $time - Votre serveur LDAP est maintenant prêt à être utilisé.        #\n"
    printf "#########################################################################\n\n\n"
    # SCRIPT COMPLETE
else
    printf "######################################################\n"
    printf "# $time - Le fichier $file n'existe pas              #\n"
    printf "######################################################\n"
fi


