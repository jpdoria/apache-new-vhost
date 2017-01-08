#!/bin/bash

# Don't touch these!
num=0
mode=755

# Text styles
bold='\033[1m'
not_bold='\033[0m'
red='\e[0;31m'
green='\e[0;32m'
no_color='\e[0m'

# Main variables
apache_root=/var/www/html
apache_logdir=/var/log/httpd
vhosts_confdir=/etc/httpd/conf.d

usage() {
echo -e "${bold}Usage: ${not_bold}$0 [-a | -r] -d google.com [-h]
\t-a : Add a virtual host
\t-r : Remove a virtual host
\t-d : Domain name
\t-h : Help"
}

create_conf() {
echo "#----- Start of configuration for $domain. -----#
# Domain: $domain
# Date: `date`
<VirtualHost *:80>
    ServerAdmin webmaster@$domain
    DocumentRoot /var/www/html/$domain
    ServerName $domain
    ServerAlias www.$domain
    ErrorLog /var/log/httpd/$domain/$domain-error_log
    CustomLog /var/log/httpd/$domain/$domain-access_log common
</VirtualHost>
#----- End of configuration for $domain. -----#" > $vhost_conf
}

add_vhost() {
	if [ ! -f $vhost_conf ]; then
		create_conf
		if [ $? -ne 0 ]; then
			echo -e "${red}${bold}Error: ${no_color}${not_bold}unable to create a new configuration."
			exit 1
		else
			for dir in ${directories[@]}; do
				if [ -d $dir ]; then
					echo -e "${red}${bold}Error: ${no_color}${not_bold}$dir already exists."
				else
					mkdir -p $dir -m $mode > /dev/null 2>&1
					if [ $? -ne 0 ]; then
						echo -e "${red}${bold}Error: ${no_color}${not_bold}unable to create $dir." 
					fi
				fi
			done
			service httpd reload
			if [ $? -eq 0 ]; then
				echo -e "${green}${bold}OK: ${no_color}${not_bold}new configuration for $domain has been added."
				exit 0
			fi
		fi
	else
		echo -e "${red}${bold}Error: ${no_color}${not_bold}$vhost_conf already exists."
		exit 1
	fi
}

remove_vhost() {
	for item in ${vhost_stuff[@]}; do
		if [[ -f $item || -d $item ]]; then
			rm -rv $item 2>/dev/null
			if [ $? -ne 0 ]; then
				echo -e "${red}${bold}Error: ${no_color}${not_bold}unable to remove $item."
			fi
		else
			echo -e "${red}${bold}Error: ${no_color}${not_bold}$item does not exist."
			num=`expr $num + 1`
		fi
	done
	string_count=`echo ${vhost_stuff[@]} | wc -w`
	if [ $num -ne $string_count ]; then
		service httpd reload
		if [ $? -eq 0 ]; then
			echo -e "${green}${bold}OK: ${no_color}${not_bold}$domain has been removed from the system."
			exit 0
		fi
	fi
}

# Only root is allowed to execute the script.
if [ $LOGNAME != "root" ]; then
	echo "${red}${bold}Error: ${no_color}${not_bold}only \"root\" is allowed to use this script."
	exit 1
fi

while getopts ":ard:h" opt; do
	case $opt in
		a)	action=add_vhost
			;;
		r)	action=remove_vhost
			;;
		d)	domain=$OPTARG
			domain=`echo $domain | tr A-Z a-z`
			vhost_conf=$vhosts_confdir/$domain.conf
			vhost_docroot=$apache_root/$domain
			vhost_logdir=$apache_logdir/$domain
			directories=("$vhost_docroot" "$vhost_logdir")
			vhost_stuff=("${directories[*]}" "$vhost_conf")
			;;
		h)	usage
			exit 1
			;;
		\?)	echo "Invalid option: -$OPTARG."
			usage
			exit 1
			;;
		:)	echo "Error: option -$OPTARG requires an argument."
			usage
			exit 1
			;;
	esac
done

if [ -z $domain ]; then
	usage
	exit 1
elif [ $action == "add_vhost" ]; then
	add_vhost
elif [ $action == "remove_vhost" ]; then
	remove_vhost
fi
