#!/bin/python3

# coding=UTF-8
#
#   Fichier     :   updateLDAP.py
#
#   Auteur      :   JHB
#
#   Description :   Mise à jour de l'Annuaire LDAP à partir d'un fichier LDIF
#                      Le script effectue les trois actions suivantes : 
#                           - Suppression des comptes dans l'OU des utilisateurs
#                           - Suppression de l'OU des utilisateurs
#                           - Import du fichier LDIF
#
#   Remarques   :   Nécessite Python 3 et le package python-ldap
#                 
#   Version     :   1.0.5
#
#   Date        :   09 mai 2020
#
#   Appel       :   sudo python3 ./updateLDAP.py [fichier LDIF]
#
#                       Si le fichier LDIF est renseigné, les suppressions sont effectuées puis l'import réalisé par root
#                       Sinon, seules les suppressions sont effectuées
#
#   TODO        [x] Tester l'existence du fichier en 1er (rien ne sert de vider l'Annuaire si on ne peut pas le remplir !)
#               [x] Arrêter slapd avant l'import puis le relancer (après ...)
#               [x] Vérifier l'OS => si Windows pas d'insertion (// pas de nom de fichier !)
#               [x] Seul 'root' peut insérer les nouvelles valeurs
#               [x] Vérifier que le script n'a pas déja été passé avec ce jeu de données
#

# La package LDAP est obligatoire !!!
try :
    import ldap
except ModuleNotFoundError:
    print("Erreur - Le package ldap (python-ldap) est introuvable")
    exit(1)
    
import os, pwd, platform, sys, hashlib
from colorizer import colorizer, backColor, textColor, textAttribute    # Pour la coloration des sorties terminal

# Constantes de l'application
#

# Version du programme
CURRENT_VERSION = "1.0.5"

# Serveur LDAP
#LDAP_SERVER = "192.168.1.15"
LDAP_SERVER = "localhost"
LDAP_USER_OU = "ou=users,dc=allier,dc=fr"

# Compte
LDAP_ADMIN_ACCOUNT = "cn=manager,dc=allier,dc=fr"
LDAP_ADMIN_PWD = "zita"

# Nombre maximal d'enregistrements
LDAP_SIZE_LIMIT = 2500

# Gestion du hash du fichier
#

# Nom du fichier pour le cache du hash du fichier LDIF importé
HASH_FILE = "/etc/scripts/.tempHash"

# Taille max. d'un paquet en octets pour le hash des fichiers (évite de saturer la mémoire si le fichier est trop volumineux)
MAX_HASH_BUF_SIZE = 16384  


# Fonctions de l'application
#

# Hashage (Sha1) d'un fichier
#
#   Retourne une chaine en hexa du hash SHA1 du fichier ou une chane vide en cas d'erreur
#
def hashFile(fileName):
    
    # Le fichier doit exister ...
    if 0 == len(fileName) or False == os.path.isfile(fileName):
        # Pas de hash !
        return ""

    # Hashage en sha1 par paquets
    sha1 = hashlib.sha1()
    with open(sys.argv[1], 'rb') as f:
        while True:
            data = f.read(MAX_HASH_BUF_SIZE)
            if not data:
                break
            sha1.update(data)

    return format(sha1.hexdigest())


# Point d'entrée
#
color = colorizer(True)

# C'est parti ...
print(color.colored("updateLDAP.py", textColor.JAUNE), " - version ", color.colored(CURRENT_VERSION, formatAttr=[textAttribute.GRAS]))


ldifFile = ""       # Nom du fichier LDIF à importer
currentHash = ""    # Hash du fichier
oldHash = ""

if platform.system() == "Windows":
    print(color.colored("[OK]", textColor.JAUNE), "Environnement MS-Windows => pas d'import possible")
    exit(1)
else:
    # Le nom du fichier est renseigné
    if len(sys.argv) > 1:
        ldifFile = sys.argv[1]

        # Il doit exister !
        if False == os.path.isfile(ldifFile):
            print(color.colored("[KO]", textColor.ROUGE), "Le fichier", ldifFile,"n'existe pas")
            exit(1)
        
        # Seul 'root' pourra importer le fichier
        if "root" != pwd.getpwuid(os.getuid())[0]:
            print(color.colored("[KO]", textColor.ROUGE), "Seul le compte 'root' peut importer le fichier LDIF")
            exit(1)

        # Calcul du hash du fichier actuel
        currentHash = hashFile(ldifFile)
        if currentHash == "" :
            # Pas de hash ....
            print(color.colored("[KO]", textColor.ROUGE), "Impossible de générer un hash pour" , repr(ldifFile))
            exit(1)
        
        # Quel est le hash actuel ?
        if False == os.path.isfile(HASH_FILE):
            print(color.colored("[OK]", textColor.JAUNE), "Pas de cache pour le hash du fichier LDIF.")
        else:
            try:
                hFile = open(HASH_FILE, "r")
                oldHash = hFile.readline()
                hFile.close()
            except:
                pass

            # Comparaison des hash
            if len(oldHash) > 0 and oldHash == currentHash:
                # Même fichier !!!
                print(color.colored("[OK]", textColor.JAUNE), "Hash identique - Le fichier", repr(ldifFile), "a déja été chargé dans l'Annuaire.")
                print(color.colored("[OK]", textColor.VERT), "Fin des traitements")
                exit(0)
            
        print(color.colored("[OK]", textColor.VERT), "Nouveau hash :", "SHA1:"+currentHash)
    else:
        # Pas de fichier => on supprime le hash
        if True == os.path.isfile(ldifFile):
            try:
                os.remove(HASH_FILE)
            except:
                pass

# Quelques affichages
if len(ldifFile) > 0:
    print("Fichier LDIF :", ldifFile)
print("Connexion au serveur LDAP :")
print("\t- Host : ", color.colored(LDAP_SERVER, formatAttr=[textAttribute.GRAS]))
print("\t- ou : ", color.colored(LDAP_USER_OU, formatAttr=[textAttribute.GRAS]))
print("\t- Compte : ", color.colored(LDAP_ADMIN_ACCOUNT, formatAttr=[textAttribute.GRAS]))

# Connexion à LDAP ...
try:
    ldapConnect = ldap.initialize('ldap://'+LDAP_SERVER)
    ldapConnect.set_option(ldap.OPT_SIZELIMIT, LDAP_SIZE_LIMIT)
    ldapConnect.simple_bind_s(LDAP_ADMIN_ACCOUNT, LDAP_ADMIN_PWD)
except ldap.LDAPError as e:
    print(color.colored("[KO]", textColor.ROUGE), "Erreur de connexion LDAP :", color.colored(e,formatAttr=[textAttribute.GRAS]))
    exit(1)

print(color.colored("[OK]", textColor.VERT),"Connecté")

# On retire tous les comptes de l'ou
removeUsers = True
try:
    res = ldapConnect.search_s(LDAP_USER_OU, ldap.SCOPE_SUBTREE, '(objectClass=inetOrgPerson)')
except ldap.LDAPError as e:
    print(color.colored("[KO]", textColor.ROUGE), "Erreur lors de la recherche des comptes utilisateurs :", color.colored(e,formatAttr=[textAttribute.GRAS]))
    removeUsers = False

if True == removeUsers:
    if None == res:
        print("Le dossier ", LDAP_USER_OU, "est vide")
    else:
        print(color.colored("[OK]", textColor.VERT),str(len(res)), "utilisateur(s) trouvé(s)")
        for dn, entry in res:
            try:
                ldapConnect.delete_s(dn)
                print(color.colored("[OK]", textColor.VERT),"Suppression de", repr(dn))
            except:
                print(color.colored("[KO]", textColor.ROUGE), "Impossible de supprimer", repr(dn))

    # Suppression de l'ou
    try:
        ldapConnect.delete_s(LDAP_USER_OU)
        print(color.colored("[OK]", textColor.VERT),"Suppression de", repr(LDAP_USER_OU))
    except:
        print(color.colored("[KO]", textColor.ROUGE), "Impossible de supprimer", repr(LDAP_USER_OU))

# Import du fichier ldif
if not 0 == len(ldifFile):
    try:       
        print(color.colored("[OK]", textColor.VERT),"Arrêt de slapd")
        os.system("systemctl stop slapd")
        print(color.colored("[OK]", textColor.VERT),"Import de", ldifFile)
        os.system("slapadd -cl \"" + ldifFile + "\"")
        print(color.colored("[OK]", textColor.VERT),"Lancement de slapd")
        os.system("systemctl start slapd")

        # Sauvegarde du hash
        if len(currentHash) > 0:
            try:
                hFile = open(HASH_FILE, "w")
                hFile.write(currentHash)
                hFile.close()
                print(color.colored("[OK]", textColor.VERT), "Fichier de cache crée")
            except:
                print(color.colored("[KO]", textColor.ROUGE), "Erreur lors de l'écriture dans le fichier de cache")
    except:
        print(color.colored("[KO]", textColor.ROUGE), "Erreur lors de l'import du fichier", ldifFile)
else:
    print(color.colored("[OK]", textColor.JAUNE), "Pas de fichier à importer")    


# Terminé
print(color.colored("[OK]", textColor.VERT),"Fin de la connexion")

# EOF