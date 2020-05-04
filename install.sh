#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


checkDistrib()
{

test=$(awk -F '=' '/PRETTY_NAME/ { print $2 }' /etc/os-release | cut -d "|" -f 2)

case $test in
	
	
	*"Ubuntu"*)
	sudo $DIR/install-Ubuntu.sh
	;;
	
	*"Debian"*)
	sudo $DIR/install-Debian.sh
	;;
	
	*"CentOS"*)
	sudo $DIR/install-CentOS.sh
	;;
	
	*)
	echo "-------------------------"
	echo "DISTRIBUTION NON DETECTER"
	echo "LANCER L'UN DES SCRIPTS SUIVANT"
	echo "install-Debian.sh"
	echo "install-Ubuntu.sh"
	echo "install-CentOS.sh"
	;;
esac
}

confirinstall()
{
read -p "Confirmer l'installation (y/n)?" choice
case "$choice" in 
  y|Y )
	checkDistrib
	;;
  n|N ) 
	exit 0
	;;
	*) 
	echo "Saisie invalide"
	confirinstall
	;;
esac
}

confirinstall

