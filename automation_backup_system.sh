#!/bin/bash

# ========================================= Config

_BACKUP_FOLDER_='/SYSTEM_BACKUP'


# _FOLDERS_=( "tmp" "var" ) # Uncomment this block if you want backup custom dir / file path instead of default (backup /)
_SKIPPED_=0
_SUCCEEDED_=0
_VERSION_="v1.0.0"
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
	           /var/spool/asterisk/monitor
	           $(pwd)/$_LOG_FILE_
	           $_BACKUP_FOLDER_"

# =========================================

# Check User, Exit if user not root
if [[ "$EUID" -ne 0 ]]
	then 
		scriptHelper
		exit
fi


# Function for check return code and show execution time
function check(){
	if [[ $? -eq 0 ]]; then
		echo -ne " [ Success ]"
		_SUCCEEDED_=$((_SUCCEEDED_+1))
	else
		echo -ne " [ Failed ]"
	fi
}


# Function for show complete statistic
function showStatistic(){

	if [[ $3 == 'script' ]]; then
		_runtime_script_=$(($2-$1))
		hours=$((_runtime_script_ / 3600)); minutes=$(( (_runtime_script_ % 3600) / 60 )); seconds=$(( (_runtime_script_ % 3600) % 60 ))

		echo -e "\n\n [+] Overall Stats"
		echo -e "  |--[+] Backup Time   -->   $hours : $minutes : $seconds"
		echo -e "  |--[+] Skipped Dir   -->   $_SKIPPED_"
		echo -e "  |--[+] Total Sizes   -->   $(du -sh $_BACKUP_FOLDER_ | awk '{printf "%s\n", $1}')"
		echo -e "  |--[+] Total Items   -->   $(printf "%'d" $(cat $_LOG_FILE_  2> /dev/null | wc -l))"
		echo -e "  |--[+] Success Item  -->   $_SUCCEEDED_"
		echo -e "\n\n"

	elif [[ $3 == 'job' ]]; then
		_runtime_job_=$(($2-$1))
		_total_item_=$(printf "%'d" $(cat $_LOG_FILE_ 2> /dev/null | grep -E '^\[ '+$4+' \]*' | wc -l))
		printf "    %7s item ( %3s s )\n" "$_total_item_" "$_runtime_job_"
	fi
}

function provision(){
	echo " [+] Provisioning"
	printf "**|--[+]*%-37s" "Removing*Log*Files*" | sed 's/ /./g' | sed 's/*/ /g'
	rm $_LOG_FILE_ > /dev/null 2>&1
	check; echo ""

	printf "**|--[+]*%-37s" "Generate*Exlude*File*" | sed 's/ /./g' | sed 's/*/ /g'
	echo -e "$_EXCLUDE_LIST_" | sed 's/ \|\t//g' > $_EXCLUDE_PATH_FILE_
	check; echo ""
	

	if [[ ! -d "$_BACKUP_FOLDER_" ]]; then
		printf "**|--[+]*%-37s" "Creating*Backup*Dir*" | sed 's/ /./g' | sed 's/*/ /g'
		mkdir $_BACKUP_FOLDER_ > /dev/null 2>&1
		check;
	fi

	echo -e "\n"
}


# Function for show help page
function scriptHelper(){
	echo -e " [!] Ouch, Make Sure You Have"
	echo -e "  |--[!] Run This Script As Root"
	echo -e "  |--[!] Provide Valid Script Parameters [ backup / restore ]"

	echo -e " \n\n [!] $(echo 'Q3JlYXRlZCBCeSBiZXJyYWJlCg==' | base64 -d)\n\n" 
}


function backup() {

	echo " [+] Backuping System"
	for folder in $(/bin/ls /); do 
	# for folder in "${_FOLDERS_[@]}"; do # Uncomment this block if you want backup custom dir / file path instead of default (backup /)


		folder="/$folder"

		printf "  |--[+] Backup "
		printf "%-30s" "$folder+" | sed 's/ /./g' | sed 's/+/ /g'



		grep -qE "^$folder$" $_EXCLUDE_PATH_FILE_
		if [[ $? -ne 0 ]]; then

			_date_=$(echo "[ $folder ] --- `date '+%d-%b-%y %H:%M:%S'`")
			_start_job_=$(date +%s)

			tar --exclude-from="$(pwd)/$_EXCLUDE_PATH_FILE_" -czvPf "$_BACKUP_FOLDER_$folder.tar.gz.$(date '+%d_%b_%y')" $folder 2>&1 | awk -v date="$_date_" '{ printf "%s |-----> backup %s\n", date, $0 }' >> $_LOG_FILE_ 2>&1
			check
			
			_end_job_=$(date +%s)
			
			showStatistic $_start_job_ $_end_job_ 'job' $folder

		else

			echo -e " [ - ]"
			_SKIPPED_=$((_SKIPPED_+1))
			continue

		fi

		sleep 1

	done
}


function restore() {

	echo " [+] Restoring System"
	for compress in $(/bin/ls $_BACKUP_FOLDER_ | grep 'tar.gz'); do

		_start_job_=$(date +%s)
		compress_clear=$(echo $compress | awk -F '.' '{printf "%s", $1}')
		_date_=$(echo "[ $compress_clear ] --- `date '+%d-%b-%y %H:%M:%S'`")
		# compress=$(echo $compress | awk -F '.' '{printf "%s", $1}')

		printf "  |--[+] Restore "
		printf "%-29s" "$compress_clear*" | sed 's/ /./g' | sed 's/*/ /g'

		tar -xzvPf "$_BACKUP_FOLDER_/$compress" 2>&1 | awk -v date="$_date_" '{ printf "%s |-----> restore %s\n", date, $0 }' >> $_LOG_FILE_ 2>&1
		check

		_end_job_=$(date +%s)
		showStatistic $_start_job_ $_end_job_ 'job' $compress_clear

	done
}


clear
echo -e " \t == Full Auto Backup System | $_VERSION_ ==\n\n"
provision

if [[ $1 == 'backup' ]]; then

	_start_script_=$(date +%s)
	backup
	_end_script_=$(date +%s)
	showStatistic $_start_script_ $_end_script_ 'script'


elif [[ $1 == 'restore' ]]; then
	
	_start_script_=$(date +%s)
	restore
	_end_script_=$(date +%s)
	showStatistic $_start_script_ $_end_script_ 'script'

else
	scriptHelper

fi