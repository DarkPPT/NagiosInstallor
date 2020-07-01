#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

addhostmenu()
{
	creefichierconf
	clear
	echo "MENU DE SELECTION"
	PS3=">"
	select item in "Ahouter un servur Linux" "Ajouter un serveur Windows" "Finir l'installation"
	do


		case "$REPLY" in


			1)
				addlinux
				break
				;;
			2)
				addwindows
				break
				;;
			3)
				clear
				/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
				break
				;;
			
			*)
				echo "Saisie Incorrecte"
				read x
				;;

		esac

	done
	
	
}

check_ip(){
	echo -e "\nIP de l'host:"
	read -r ip
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		echo "OK"
	else
		clear
		echo -e "\nMauvais format!"
		
		check_ip
	fi
}

creefichierconf()
{

mkdir /usr/local/nagios/etc/servers
mkdir /usr/local/nagios/etc/templates

if [ ! -f "/usr/local/nagios/etc/templates/template_host.cfg" ]; then


	echo "## Default Windows Host Template ##
	define host{
	name                            <hostdefinition>               ; Name of this template
	use                             generic-host            ; Inherit default values
	check_period                    24x7        
	check_interval                  5       
	retry_interval                  1       
	max_check_attempts              10      
	check_command                   check-host-alive
	notification_period             24x7    
	notification_interval           30      
	notification_options            d,r     
	contact_groups                  admins  
	register                        0                       
	}

	## Default
	define host{
	use                             <hostdefinition>               ; Inherit default values from a template
	host_name                       <host>		        ; The name we're giving to this server
	alias                           <host>                ; A longer name for the server
	address                         <ip>            ; IP address of Remote <host> host
	}"  | sudo tee -a /usr/local/nagios/etc/templates/template_host.cfg

fi

if [ ! -f "/usr/local/nagios/etc/templates/Linux_template_services.cfg" ];then
echo "###############################################################################
#
# SERVICE DEFINITIONS
#
###############################################################################

# Define a service to \"ping\" the local machine

define service {

    use                     generic-service          ; Name of service template to use
    host_name               <host>
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}



# Define a service to check the disk space of the root partition
# on the local machine.  Warning if < 20% free, critical if
# < 10% free space on partition.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     Root Partition
    check_command           check_local_disk!20%!10%!/
}



# Define a service to check the number of currently logged in
# users on the local machine.  Warning if > 20 users, critical
# if > 50 users.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     Current Users
    check_command           check_local_users!20!50
}



# Define a service to check the number of currently running procs
# on the local machine.  Warning if > 250 processes, critical if
# > 400 processes.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     Total Processes
    check_command           check_local_procs!250!400!RSZDT
}



# Define a service to check the load on the local machine.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     Current Load
    check_command           check_local_load!5.0,4.0,3.0!10.0,6.0,4.0
}



# Define a service to check the swap usage the local machine.
# Critical if less than 10% of swap is free, warning if less than 20% is free

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     Swap Usage
    check_command           check_local_swap!20%!10%
}



# Define a service to check SSH on the local machine.
# Disable notifications for this service by default, as not all users may have SSH enabled.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     SSH
    check_command           check_ssh
    notifications_enabled   0
}



# Define a service to check HTTP on the local machine.
# Disable notifications for this service by default, as not all users may have HTTP enabled.

define service {

    use                     generic-service           ; Name of service template to use
    host_name               <host>
    service_description     HTTP
    check_command           check_http
    notifications_enabled   0
}" | sudo tee -a /usr/local/nagios/etc/templates/Linux_template_services.cfg
fi

if [ ! -f "/usr/local/nagios/etc/templates/Windows_template_services.cfg" ];then
echo "
define service {

    use                     generic-service
    host_name               <host>
    service_description     NSClient++ Version
    check_command           check_nt!CLIENTVERSION
}



# Create a service for monitoring the uptime of the server
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     Uptime
    check_command           check_nt!UPTIME
}



# Create a service for monitoring CPU load
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     CPU Load
    check_command           check_nt!CPULOAD!-l 5,80,90
}



# Create a service for monitoring memory usage
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     Memory Usage
    check_command           check_nt!MEMUSE!-w 80 -c 90
}



# Create a service for monitoring C:\ disk usage
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     C:\ Drive Space
    check_command           check_nt!USEDDISKSPACE!-l c -w 80 -c 90
}



# Create a service for monitoring the W3SVC service
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     W3SVC
    check_command           check_nt!SERVICESTATE!-d SHOWALL -l W3SVC
}



# Create a service for monitoring the Explorer.exe process
# Change the host_name to match the name of the host you defined above

define service {

    use                     generic-service
    host_name               <host>
    service_description     Explorer
    check_command           check_nt!PROCSTATE!-d SHOWALL -l Explorer.exe
}" | sudo tee -a /usr/local/nagios/etc/templates/Windows_template_services.cfg
fi

}

addlinux()
{
echo "Nom du host:"

read -r host

if [ -z "$host" ]
then
	clear
	echo "L'host ne peut pas être vide"
	addwindows
else

	check_ip



	cp /usr/local/nagios/etc/templates/template_host.cfg /usr/local/nagios/etc/servers/"${host}_host.cfg"
	cp /usr/local/nagios/etc/templates/Linux_template_services.cfg /usr/local/nagios/etc/servers/"${host}_services.cfg"

	chown nagios /usr/local/nagios/etc/servers/"${host}_host.cfg"
	chgrp nagios /usr/local/nagios/etc/servers/"${host}_host.cfg"

	chown nagios /usr/local/nagios/etc/servers/"${host}_services.cfg"
	chgrp nagios /usr/local/nagios/etc/servers/"${host}_services.cfg"

	sed -i "s/<ip>/$ip/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<host>/$host/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<hostdefinition>/$host-windows/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<host>/$host/g" /usr/local/nagios/etc/servers/"${host}_services.cfg"	


	echo "cfg_file=/usr/local/nagios/etc/servers/${host}_host.cfg" | sudo tee -a /usr/local/nagios/etc/nagios.cfg
	echo "cfg_file=/usr/local/nagios/etc/servers/${host}_services.cfg" | sudo tee -a /usr/local/nagios/etc/nagios.cfg		
		
	systemctl restart nagios

	clear
	addhostmenu
fi

}

addwindows()
{
	echo "Nom du host:"

read -r host

if [ -z "$host" ]
then
	clear
	echo "L'host ne peut pas être vide"
	addwindows
else

	check_ip


	cp /usr/local/nagios/etc/templates/template_host.cfg /usr/local/nagios/etc/servers/"${host}_host.cfg"
	cp /usr/local/nagios/etc/templates/Windows_template_services.cfg /usr/local/nagios/etc/servers/"${host}_services.cfg"

	chown nagios /usr/local/nagios/etc/servers/"${host}_host.cfg"
	chown nagios /usr/local/nagios/etc/servers/"${host}_services.cfg"

	chgrp nagios /usr/local/nagios/etc/servers/"${host}_host.cfg"
	chgrp nagios /usr/local/nagios/etc/servers/"${host}_services.cfg"

	sed -i "s/<ip>/$ip/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<host>/$host/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<hostdefinition>/$host-windows/g" /usr/local/nagios/etc/servers/"${host}_host.cfg"
	sed -i "s/<host>/$host/g" /usr/local/nagios/etc/servers/"${host}_services.cfg"		

	echo "cfg_file=/usr/local/nagios/etc/servers/${host}_host.cfg" | sudo tee -a /usr/local/nagios/etc/nagios.cfg
	echo "cfg_file=/usr/local/nagios/etc/servers/${host}_services.cfg" | sudo tee -a /usr/local/nagios/etc/nagios.cfg		
		
	systemctl restart nagios

	clear
	addhostmenu

fi

}



addhostmenu
