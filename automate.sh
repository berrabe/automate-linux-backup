#!/bin/bash

# ========================================= Config

_BACKUP_FOLDER_='/SYSTEM_BACKUP'


# _FOLDERS_=( "tmp" "var" ) # Uncomment this block if you want backup custom dir / file path instead of default (backup /)
_SKIPPED_=0
_SUCCEEDED_=0
_VERSION_="v1.2.0"
_EXCLUDE_PATH_FILE_="exclude.txt"
_LOG_FILE_="output.log"

# List of exluded dir / file which will not be compressed
_EXCLUDE_LIST_="/boot
	           /dev
	           /tmp
	           /sys
	           /proc
	           /backup
	           /etc/fstab
	           /etc/mtab
	           /etc/mdadm.conf
	           /etc/sysconfig/network*
	           /etc/network/interfaces
	           /var/spool/asterisk/monitor
	           $(pwd)/$_LOG_FILE_
	           $_BACKUP_FOLDER_"

# =========================================

# List of Colors
Light_Red="\033[1;31m"
Light_Green="\033[1;32m"
Yellow="\033[1;33m"
Light_Blue="\033[1;34m"
Light_Purple="\033[1;35m"
Light_Cyan="\033[1;36m"
NoColor="\033[0m"

# Function for check return code and show execution time
function check(){
	if [[ $? -eq 0 && ${PIPESTATUS[0]} -eq 0 ]]; then
		echo -ne "${Light_Green} [ Success ]${NoColor}"
		_SUCCEEDED_=$((_SUCCEEDED_+1))
	else
		echo -ne "${Light_Red} [ Failed  ]${NoColor}"
	fi
}


function checkSum(){

	if [[ $2 == 'backup' ]]; then

		hash=$(md5sum $1 | awk '{print $1}')
		mv $1 "$1.$hash"

	elif [[ $2 == 'restore' ]]; then
		parsed_hash=$(echo $1 | awk -F '.' '{print $NF}')
		check_hash=$(md5sum $1 | awk '{print $1}')

		if [[ $parsed_hash == $check_hash ]]; then
			return 0
		else
			return 1
		fi
	fi
}


# Function for show complete statistic
function showStatistic(){

	if [[ $3 == 'script' ]]; then
		_runtime_script_=$(($2-$1))
		hours=$((_runtime_script_ / 3600)); minutes=$(( (_runtime_script_ % 3600) / 60 )); seconds=$(( (_runtime_script_ % 3600) % 60 ))

		echo -e "\n\n${Light_Cyan} [+] Overall Stats ${NoColor}"
		echo -e "  |--[+] Backup Time   -->   $hours : $minutes : $seconds"
		echo -e "  |--[+] Skipped Dir   -->   $_SKIPPED_"
		echo -e "  |--[+] Total Sizes   -->   $(du -sh $_BACKUP_FOLDER_ | awk '{printf "%s\n", $1}')"
		echo -e "  |--[+] Total Items   -->   $(printf "%'d" $(cat $_LOG_FILE_  2> /dev/null | grep -wE '(backup|restore) \/?' | wc -l))"
		echo -e "  |--[+] Job Success   -->   $_SUCCEEDED_"
		echo -e "  |--[+] Warn / Err    -->   $(printf "%'d" $(cat $_LOG_FILE_  2> /dev/null | grep -vE '(backup|restore) /' | wc -l))"
		echo -e "\n\n"

	elif [[ $3 == 'job' ]]; then
		_runtime_job_=$(($2-$1))
		_total_item_=$(cat $_LOG_FILE_ 2> /dev/null | grep -wE '(restore|backup) '+$4'' | wc -l)
		_total_item_parsed_=$(printf "%'d" $_total_item_)

		if [[ $_total_item_ -ge 100 && $_total_item_ -le 500 ]]; then
			printf "${Yellow}    %7s item ( %3s s )\n${NoColor}" "$_total_item_parsed_" "$_runtime_job_"
		elif [[ $_total_item_ -ge 500 && $_total_item_ -le 5000 ]]; then
			printf "${Light_Blue}    %7s item ( %3s s )\n${NoColor}" "$_total_item_parsed_" "$_runtime_job_"
		elif [[ $_total_item_ -ge 5000 ]]; then
			printf "${Light_Purple}    %7s item ( %3s s )\n${NoColor}" "$_total_item_parsed_" "$_runtime_job_"
		else
			printf "    %7s item ( %3s s )\n" "$_total_item_parsed_" "$_runtime_job_"
		fi
	fi
}

function provision(){
	echo -e "${Light_Cyan} [+] Provisioning ${NoColor}"
	printf "**|--[+]*%-37s" "Removing*Log*Files*" | sed 's/ /./g' | sed 's/*/ /g'
	rm $_LOG_FILE_ > /dev/null 2>&1
	check; echo ""

	printf "**|--[+]*%-37s" "Generate*Exlude*File*" | sed 's/ /./g' | sed 's/*/ /g'
	echo -e "$_EXCLUDE_LIST_" | sed 's/ \|\t//g' > $_EXCLUDE_PATH_FILE_
	check; echo ""
	

	if [[ ! -d "$_BACKUP_FOLDER_" ]]; then
		printf "**|--[+]*%-37s" "Creating*Backup*Dir*" | sed 's/ /./g' | sed 's/*/ /g'
		mkdir $_BACKUP_FOLDER_ > /dev/null 2>&1
		check; echo ""
	fi

	echo -e "\n"
}


# Function for show help page
function scriptHelper(){
	echo -e "${Light_Red} [!] Ouch, Make Sure You Have ${NoColor}"
	echo -e "  |--[!] Run This Script As Root"
	echo -e "  |--[!] Provide Valid Script Parameters [ backup / restore ]"

	echo -e " \n\n [!] $(echo 'Q3JlYXRlZCBCeSBiZXJyYWJlCg==' | base64 -d)\n\n" 
}


function backup() {

	echo -e "${Light_Cyan} [+] Backuping System ${NoColor}"
	for folder in $(/bin/ls /); do 
	# for folder in "${_FOLDERS_[@]}"; do # Uncomment this block if you want backup custom dir / file path instead of default (backup /)


		folder="/$folder"

		printf "  |--[+] Backup "
		printf "%-30s" "$folder+" | sed 's/ /./g' | sed 's/+/ /g'



		grep -qE "^$folder$" $_EXCLUDE_PATH_FILE_
		if [[ $? -ne 0 ]]; then

			_item_=$(echo "[ $folder ] ---")
			_start_job_=$(date +%s)

			tar --exclude-from="$(pwd)/$_EXCLUDE_PATH_FILE_" -czvPf "$_BACKUP_FOLDER_$folder.tar.gz.$(date '+%d_%b_%y')" $folder 2>&1 | awk -v item="$_item_" '{ printf "%s %s |-----> backup %s\n", item, strftime("%d-%b-%y %H:%M:%S"), $0 }' >> $_LOG_FILE_ 2>&1
			check

			checkSum  "$_BACKUP_FOLDER_$folder.tar.gz.$(date '+%d_%b_%y')" "backup"
			
			_end_job_=$(date +%s)
			showStatistic $_start_job_ $_end_job_ 'job' $folder


		else

			echo -e " [ - ]"
			_SKIPPED_=$((_SKIPPED_+1))
			continue

		fi

	done
}


function restore() {

	echo -e "${Light_Cyan} [+] Restoring System ${NoColor}"

	if [[ $(/bin/ls $_BACKUP_FOLDER_ | grep 'tar.gz' | wc -l) -eq 0 ]]; then
		printf "  |--[+] %s Empty\n" "$_BACKUP_FOLDER_"
	fi

	for compress in $(/bin/ls $_BACKUP_FOLDER_ | grep 'tar.gz'); do

		_start_job_=$(date +%s)
		compress_clear=$(echo $compress | awk -F '.' '{printf "/%s", $1}')
		_item_=$(echo "[ $compress_clear ] ---")

		printf "  |--[+] Restore "
		printf "%-29s" "$compress_clear*" | sed 's/ /./g' | sed 's/*/ /g'

		checkSum "$_BACKUP_FOLDER_/$compress" "restore"
		if [[ $? -ne 0 ]]; then
			echo "${Light_Red} [ Checksum Error ]${NoColor}"
			continue
		fi

		tar -xzvPf "$_BACKUP_FOLDER_/$compress" 2>&1 | awk -v item="$_item_" '{ printf "%s %s |-----> restore %s\n", item, strftime("%d-%b-%y %H:%M:%S"), $0 }' >> $_LOG_FILE_ 2>&1
		check

		_end_job_=$(date +%s)
		showStatistic $_start_job_ $_end_job_ 'job' $compress_clear

	done
}


clear
echo -e " \t == Automate Backup System | $_VERSION_ ==\n\n"

# Check User, Exit if user not root
if [[ "$EUID" -ne 0 ]]
	then 
		scriptHelper
		exit
fi

if [[ $1 == 'backup' ]]; then

	provision
	_start_script_=$(date +%s)
	backup
	_end_script_=$(date +%s)
	showStatistic $_start_script_ $_end_script_ 'script'


elif [[ $1 == 'restore' ]]; then
	
	provision
	_start_script_=$(date +%s)
	restore
	_end_script_=$(date +%s)
	showStatistic $_start_script_ $_end_script_ 'script'

else
	scriptHelper

fi
