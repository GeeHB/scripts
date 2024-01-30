#!/bin/bash

#
#	proxyAllier.sh
#
#	Auteur	: JHB
#
#	Version	: 4.0.10 - 23 juillet 2019
#
#	Description	: Mise en place ou retrait des paramètres proxy en fonction de la classe d'adresse
#				  Testé sur Fedora 29/Gnome 3
#
#	Attention : le script est lancé par root 
#
#				les commandes à executer à l'utilisateur courant le seront avant celles
#				à éxecuter par root
#

APP_VERSION="4.0.10"

# Le dossier de scripts ...
#
SCRIPT_FOLDER="/etc/scripts"
cd $SCRIPT_FOLDER

# Constantes externes de l'application
#
source "./sources/proxy.config"

#
# Commandes à exécuter
#
#	La commande est :
#		- soit une commandes bash
#		- soit un fichier à tokeniser avec sed : {[fichiersource];[fichier destination]}
#

# Mise en place du proxy 
#

# ... pour la mise en place du proxy par root
CMD_PROXY_ROOT=(
	"{/etc/scripts/sources/varProxyAllier.sh;/etc/profile.d/proxyAllier.sh}"
	"{/etc/scripts/sources/dnf.conf.proxy;/etc/dnf/dnf.conf}" 
	)

# ... pour la mise en place du proxy par l'utilisateur
CMD_PROXY_USER=(
	"dropbox proxy \"manual\" \"http\" $PROXY_HOST $PROXY_PORT $PROXY_USER $PROXY_PWD" 
	"{/etc/scripts/sources/.gitconfig.proxy;~/.gitconfig}"
	"gsettings set org.gnome.system.proxy mode 'manual'"
	"gsettings set org.gnome.system.proxy.http host $PROXY_HOST"
	"gsettings set org.gnome.system.proxy.http port $PROXY_PORT"
	"gsettings set org.gnome.system.proxy.http authentication-user $PROXY_USER"
	"gsettings set org.gnome.system.proxy.http authentication-password $PROXY_PWD"  
	"gsettings set org.gnome.system.proxy.https host $PROXY_HOST"
	"gsettings set org.gnome.system.proxy.https port $PROXY_PORT"	
	"gsettings set org.gnome.system.proxy ignore-hosts \"['localhost', '127.0.0.0/8', '::1', 'gestor-p-web0.cg03.local', 'segallier.intranet.cd03.fr', 'casarray.cg03.local', 'bpmt.cg03.local', 'organigramme.allier.fr' , 'no031.cg03.local']\" "
	)

#	Retrait du proxy
#

# ... ou pour le retrait du proxy par root
CMD_NOPROXY_ROOT=(
	"rm /etc/profile.d/proxyAllier.sh"
	"{/etc/sources/dnf.conf.noproxy;/etc/dnf/dnf.conf}"
	)

# ... ou pour le retrait du proxy
CMD_NOPROXY_USER=(
	"dropbox proxy \"none\"" 
	"rm ~/.gitconfig"
	"gsettings set org.gnome.system.proxy mode 'none'"
	)

#
# Fonctions à usage interne
#

# Création de la commande bash qui va générer d'un fichier de paramètres
#	Le fichier destination est généré en remplaçant les tokens trouvés dans le fichier source	
#
#   $1 = ligne de commande au format {fichier source;fichier destination}
#
#	Retourne la commande 'sed' complète
#
_sed(){
	# Récupération des 2 noms de fichiers
	valid=0
	commandLine=$1
	len=${#commandLine}
	if [ $len -gt 0 ];then
		from=$(expr index "$commandLine" "{")
		if [ $from == 1 ];then
			to=$(expr index "$commandLine" "}")
			if [ $to != 0 ];then
				sep=$(expr index "$commandLine" ";")
				if [ $sep -gt $from ];then
					srcName=${commandLine:1:(sep-from-1)}
					destName=${commandLine:$sep:$to-$sep-1}
					valid=1
				fi
			fi
		fi
	fi

	if [ $valid == 1 ]; then
		echo "sed 's|PROXY_PROTOCOL|$PROXY_PROTOCOL|g;s|PROXY_HTTPS_PROTOCOL|$PROXY_HTTPS_PROTOCOL|g;s|PROXY_HOST|$PROXY_HOST|g;s|PROXY_PORT|$PROXY_PORT|g;s|PROXY_USER|$PROXY_USER|g;s|PROXY_PWD|$PROXY_PWD|g' $srcName > $destName"
	fi
}

#
# Traitements ...
#
echo "Changement du proxy version $APP_VERSION"
echo "Lancement des traitements"

#command=$(_sed "{./sources/dnf.conf.proxy;./dnf.conf}")
#echo $command
#exit

# Adresse IP du poste
#
# myIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')

# L'adresse IPV4 est la deuxième "valeur" affichée
#myIP=$(ifconfig | grep "inet $PRO_IP" | awk '{print $2}' | cut -f 2 )
myIP=$(ifconfig | grep "inet $INTERNAL_IP_STARTS_WITH")
myIPLen=${#myIP}

if [ -f "$TEMP_SCRIPT_FILE" ]; then
	echo "Suppression du script temporaire"
	rm $TEMP_SCRIPT_FILE
fi

# Adresse professionnelle ?
#if [ ${myIP:0:$PRO_IP_LENGTH} = ${PRO_IP:0:$PRO_IP_LENGTH} ]; then
if [ "$myIPLen" -gt 0 ]; then
	echo "Adresse(s) du poste : $myIP"
	echo "Réseau professionnel - Installation du proxy"
	
	# Commande(s) pour l'utilisateur => génération d'un script
	cmdCount=${#CMD_PROXY_USER[@]}
	if [ $cmdCount -gt 0 ]; then
		echo "$cmdCount commande(s) à éxécuter par '$USER_ME'"
		for i in `seq 1 $cmdCount`
		do
			let "index = $i-1"

			# Si la commande est liée à dropbox, on peut attendre 1s.,
			# le temps pour le daemon de prendre en compte la modification
			if [[ ${CMD_PROXY_USER[$index]} == *"dropbox"* ]]; then
				echo "#!/bin/bash" >> $TEMP_SCRIPT_FILE
				echo "output=\"\$(${CMD_PROXY_USER[$index]})\"" >> $TEMP_SCRIPT_FILE
				echo "if [ \"\$output\" != \"Dropbox is\'nt running!\" ]; then" >> $TEMP_SCRIPT_FILE
				echo "still=10" >> $TEMP_SCRIPT_FILE
				echo "echo 'Dropbox => on attend un peu ...'"  >> $TEMP_SCRIPT_FILE
				echo "while [ \"\$output\" != \"set\" ] && [ \$still -ne 0 ];do" >> $TEMP_SCRIPT_FILE
				echo "echo 'on attend encore un peu ...'"  >> $TEMP_SCRIPT_FILE
				echo "((still--))" >> $TEMP_SCRIPT_FILE
				echo "sleep 1s" >> $TEMP_SCRIPT_FILE
				echo "output=\"\$(${CMD_PROXY_USER[$index]})\"" >> $TEMP_SCRIPT_FILE
				echo "done"  >> $TEMP_SCRIPT_FILE
				echo "if [ \$still -eq 0 ]; then" >> $TEMP_SCRIPT_FILE
				echo "echo \"Impossible d'arrêter Dropbox\"" >> $TEMP_SCRIPT_FILE
				echo "else"  >> $TEMP_SCRIPT_FILE
				echo "dropbox start" >> $TEMP_SCRIPT_FILE
				echo "${CMD_PROXY_USER[$index]}" >> $TEMP_SCRIPT_FILE
				echo "echo 'Dropbox est paramétré ...'"  >> $TEMP_SCRIPT_FILE
				echo "fi"  >> $TEMP_SCRIPT_FILE
				echo "fi" >> $TEMP_SCRIPT_FILE
			else
				line=${CMD_PROXY_USER[$index]}
				if [[ $line == *"{"* ]]; then
					# Une commande "sed"
					sedCmd=$(_sed "$line")
					echo $sedCmd >> $TEMP_SCRIPT_FILE
				else
					# Une "simple" commande bash
					echo $line >> $TEMP_SCRIPT_FILE
				fi
			fi
		done

		# Lancement du script
		su $USER_ME $TEMP_SCRIPT_FILE
	else
		echo "Pas de commande à éxecuter par '$USER_ME'"
	fi

	# puis les commandes exécutées par root
	cmdCount=${#CMD_PROXY_ROOT[@]}
	if [ $cmdCount -gt 0 ]; then
		echo "$cmdCount commande(s) à éxécuter en tant que root"
		for i in `seq 1 $cmdCount`
		do
			let "index = $i-1"
			line=${CMD_PROXY_ROOT[$index]}
			if [[ $line == *"{"* ]]; then
				# Une commande "sed"
				sedCmd=$(_sed "$line")
				eval ${sedCmd}
			else
				# Une commande bash
				eval ${CMD_PROXY_ROOT[$index]}
			fi
		done
	else
		echo "Pas de commande à éxecuter par root"
	fi
else
	echo "Réseau domestique - Retrait du proxy"
	
	# Les commandes à éxecuter par l'utilisateur => génération d'un script
	cmdCount=${#CMD_NOPROXY_USER[@]}
	if [ $cmdCount -gt 0 ]; then
		echo "$cmdCount commande(s) à éxécuter par '$USER_ME'"
		
		for i in `seq 1 $cmdCount`
		do
			let "index = $i-1"

			# Si la commande est liée à dropbox, on peut attendre quelques sec.,
			# le temps pour le daemon de prendre en compte la modification
			if [[ ${CMD_NOPROXY_USER[$index]} == *"dropbox"* ]]; then
				echo "#!/bin/bash" >> $TEMP_SCRIPT_FILE
				echo "output=\"\$(${CMD_NOPROXY_USER[$index]})\"" >> $TEMP_SCRIPT_FILE
				echo "if [ \"\$output\" != \"Dropbox is\'nt running!\" ]; then" >> $TEMP_SCRIPT_FILE
				echo "still=10" >> $TEMP_SCRIPT_FILE
				echo "echo 'Dropbox => on attend un peu ...'"  >> $TEMP_SCRIPT_FILE
				echo "while [ \"\$output\" != \"set\" ] && [ \$still -ne 0 ];do" >> $TEMP_SCRIPT_FILE
				echo "echo 'on attend encore un peu ...'"  >> $TEMP_SCRIPT_FILE
				echo "((still--))" >> $TEMP_SCRIPT_FILE
				echo "sleep 1s" >> $TEMP_SCRIPT_FILE
				echo "output=\"\$(${CMD_NOPROXY_USER[$index]})\"" >> $TEMP_SCRIPT_FILE
				echo "done"  >> $TEMP_SCRIPT_FILE
				echo "if [ \$still -eq 0 ]; then" >> $TEMP_SCRIPT_FILE
				echo "echo \"Impossible d'arrêter Dropbox\"" >> $TEMP_SCRIPT_FILE
				echo "else"  >> $TEMP_SCRIPT_FILE
				echo "dropbox start"  >> $TEMP_SCRIPT_FILE
				echo "output=\"\$(${CMD_NOPROXY_USER[$index]})\"" >> $TEMP_SCRIPT_FILE
				echo "echo 'Dropbox est paramétré ...'"  >> $TEMP_SCRIPT_FILE
				echo "fi" >> $TEMP_SCRIPT_FILE
				echo "fi"  >> $TEMP_SCRIPT_FILE
			else
				line=${CMD_NOPROXY_USER[$index]}
				if [[ $line == *"{"* ]]; then
					# Une commande "sed"
					sedCmd=$(_sed "$line")
					echo $sedCmd >> $TEMP_SCRIPT_FILE
				else
					# Une "simple" commande bash
					echo $line >> $TEMP_SCRIPT_FILE
				fi
			fi
		done

		# Lancement du script
		su $USER_ME $TEMP_SCRIPT_FILE
	else
		echo "Pas de commande à éxecuter par '$USER_ME'"
	fi

	# Puis les commandes exécutées par root
	cmdCount=${#CMD_NOPROXY_ROOT[@]}
	if [ $cmdCount -gt 0 ]; then
		echo "$cmdCount commande(s) à éxécuter en tant que root"
		
		for i in `seq 1 $cmdCount`
		do
			let "index = $i-1"
			line=${CMD_NOPROXY_ROOT[$index]}
			if [[ $line == *"{"* ]]; then
				# Une commande "sed"
				sedCmd=$(_sed "$line")
				eval ${sedCmd}
			else
				# Une commande bash
				eval ${CMD_NOPROXY_ROOT[$index]}
			fi
		done
	else
		echo "Pas de commande à éxecuter"
	fi
fi

if [ -f "$TEMP_SCRIPT_FILE" ]; then
	echo "Suppression du script temporaire"
	rm $TEMP_SCRIPT_FILE
fi

echo "Fin des traitements"
