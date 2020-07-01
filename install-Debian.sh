#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

addLoginPassword()
{ 
	read -p "Login du compte admin nagios: " login
	
	if [ -z "$login" ]; then
		echo -e "\nErreu de saisie (a-z) (A-Z) (0-9)"
		addLoginPassword
	
	else
		read -s -p "Mot de passe du compte $login: " password
		read -s -p "Répéter le mot de passe: " password2
		
		
		if [ -z "$password" ]
		then
			echo "Le mot de passe ne peut pas être vide"
			addLoginPassword
		elif [ $password != $password2 ]
		then
			echo "Les mots de passe ne correspondent pas"
			addLoginPassword
		fi
	fi
}


downloadSources(){	
	clear
	echo "-------------------------------------------"
	echo "	TELECHARGEMENT DES DEPENDANCES"
	echo "-------------------------------------------"
	apt-get update
	apt-get install -y autoconf gcc libc6 make wget unzip apache2 apache2-utils php libgd-dev libmcrypt-dev libssl-dev bc gawk dc build-essential snmp libnet-snmp-perl gettext ipcalc
	
	echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
	echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
	apt-get install -y iptables-persistent
	
	clear

	echo "-------------------------------------------"
	echo "	TELECHARGEMENT DE NAGIOS CORE"
	echo "-------------------------------------------"

	wget -O /tmp/nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.5.tar.gz 
	tar zxf /tmp/nagioscore.tar.gz -C /tmp
	
	clear
	
	echo "-------------------------------------------"
	echo "	TELECHARGEMENT DES PLUGINS  						"
	echo "-------------------------------------------"
	
	wget --no-check-certificate -O /tmp/nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.2.1.tar.gz 
	tar zxf /tmp/nagios-plugins.tar.gz -C /tmp
	
	clear
	
	echo "-------------------------------------------"
	echo "	TELECHARGEMENT DE NRPE"
	echo "-------------------------------------------"
	wget -O /tmp/nrpe-3.2.1.tar.gz https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-3.2.1/nrpe-3.2.1.tar.gz 
	tar zxf /tmp/nrpe-3.2.1.tar.gz -C /tmp
	clear
	
	
	
}

installNagios()
{
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DE NAGIOSCORE"
	echo "-------------------------------------------"
	cd /tmp/nagioscore-nagios-4.4.5
	
	clear
	echo "-------------------------------------------"
	echo "	COMPILATION"
	echo "-------------------------------------------"
	
	./configure --with-httpd-conf=/etc/apache2/sites-enabled
	make all

	clear
	echo "-------------------------------------------"
	echo "	AJOUT DE L'UTILISATEUR ET DU GROUP NAGIOS"
	echo "-------------------------------------------"

	make install-groups-users
	usermod -a -G nagios www-data
	
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DU BINAIRE"
	echo "-------------------------------------------"

	make install
	
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DU SERVICE DAEMON"
	echo "-------------------------------------------"

	make install-daemoninit
	
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DES COMMADES EXTERNES"
	echo "-------------------------------------------"

	make install-commandmode

	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DES FICHIER DE CONFIGURATIONS"
	echo "-------------------------------------------"

	make install-config

	clear
	echo "-------------------------------------------"
	echo "	CONFIGURATION DU SERVICE APACHE"
	echo "-------------------------------------------"

	make install-webconf
	a2enmod rewrite
	a2enmod cgi
	
	clear
	echo "-------------------------------------------"
	echo "	CREATION DE L'UTILISATEUR $login"
	echo "-------------------------------------------"

	htpasswd -b -c /usr/local/nagios/etc/htpasswd.users $login $password
	sed -i "s/nagiosadmin/$login/g" /usr/local/nagios/etc/cgi.cfg
	systemctl restart apache2.service

	systemctl start nagios.service
	
	systemctl enable nagios
}

installPlugins()
{
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DES PLUGINS"
	echo "-------------------------------------------"
	cd /tmp/nagios-plugins-release-2.2.1/
	./tools/setup
	./configure
	make
	make install
	
	systemctl restart nagios.service
}

installNRPE()
{
	clear
	echo "-------------------------------------------"
	echo "	INSTALLATION DE NRPE"
	echo "-------------------------------------------"
	cd /tmp/nrpe-3.2.1
	./configure
	make all
	make install-daemon
	
	echo "###############################################################################
# NRPE CHECK COMMAND
#
# Command to use NRPE to check remote host systems
###############################################################################

define command{
        command_name check_nrpe
        command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
        }" | sudo tee -a /usr/local/nagios/etc/objects/commands.cfg

	systemctl restart nagios.service
}


cleanInstall()
{

	rm /tmp/nagioscore.tar.gz
	rm /tmp/nagios-plugins.tar.gz
	rm /tmp/nrpe-3.2.1.tar.gz
	
	rm -r /tmp/nagioscore-nagios-4.4.5
	rm -r /tmp/nrpe-3.2.1
	rm -r /tmp/nagios-plugins-release-2.2.1

}

installFinish()
{
	clear
	
	/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
	echo "-------------------------------------------"
	echo "	INSTALLATION TERMINE"
	echo "-------------------------------------------"
	echo "ACCESS WEB:"
	ipadd="$(ip addr show | grep 'inet' | grep -v '127.0.0.1/8' | awk '{print $2}' | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')"
	echo http://$ipadd/nagios
	echo "-------------------------------------------"
	
	cleanInstall
	
	exit 0
}

IptablesRules()
{

	net = $(ipcalc $(hostname -I | awk '{print $1}') | grep Network | awk '{split($0,a," "); print 'a[2]'}')
	ipad = $(hostname -I | awk '{print $1}')

	# Delete All Existing Rules
	iptables --flush

	# Set Default Chain Policies
	iptables -P INPUT DROP
	iptables -P OUTPUT ACCEPT
	iptables -P FORWARD ACCEPT

	## Allow Loopback
	iptables -A INPUT -i lo -j ACCEPT

	## Allow Established and Related Connections
	iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

	## Allow SSH (From LAN)
	iptables -A INPUT -s $net -p tcp -m tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT

	## Allow ICMP "ping" (From LAN)
	iptables -A INPUT -s $net -p icmp -m icmp --icmp-type echo-request -j ACCEPT

	## Allow RSYNC (From LAN)
	iptables -A INPUT -s $net -p tcp -m tcp --dport 873 -m state --state NEW,ESTABLISHED -j ACCEPT

	## Allow HTTP
	iptables -A INPUT -p tcp -m tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT

	## Allow NRPE Client Access (From Nagios Server)
	iptables -A INPUT -s $ipad -p tcp -m tcp --dport 5666 -m state --state NEW,ESTABLISHED -j ACCEPT


	## Prevent HTTP DoS Attack
	iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT

	iptables-save > /etc/iptables/rules.v4


}


addLoginPassword
downloadSources
installNagios
installPlugins
installNRPE
IptablesRules
installFinish