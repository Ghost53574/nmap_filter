#!/bin/bash

# Take a file argument as input for processing
FILE="$1"
ARGS="$#"

#Text color output
NC='\e[0m'               # Text Reset
BCyan='\e[1;36m'         # Cyan
Red='\e[0;31m'           # Red
Green='\e[0;32m'         # Green

#Create static global variables
TEMP="/tmp"
TEMP_RAND=""
IFS=' '

#declare variables that will change during shell execution
declare -i IP_COUNT
declare -i SERVICE_COUNT
declare -a ARRAY_IP
declare -a ARRAY_SRV

#Colored output
echo_info() {
	echo -e "${Green}$1${NC}"
}

echo_service() {
	echo -e "${Red}$1${NC}"
}

echo_ip() {
	echo -e "${BCyan}$1${NC}"
}

#Help menu
help_menu() {
	echo_info """
	Please run this script like: ./runge.sh [nmap_output]
	"""
}

#Checking args
check_args() {
	if [[ "$ARGS" -ne 1 ]]
	then
		help_menu
		exit 1
	fi
}

#Create temp directory to work out of
create_temp() {
	TEMP_RAND="$(tr -dc '[:alnum:]' < /dev/urandom | dd bs=4 count=3 2>/dev/null)"
	mkdir "$TEMP/$TEMP_RAND"
}

#Create initial dataset
create_dataset() {
	DATASET="$(cat "$FILE" | grep -E '^(?>!Warning)*' | grep -E 'open|(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9])[.]){3}(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9]))' - | grep -v 'Warning')"
	IP_COUNT=0
	SERVICE_COUNT=0
	ARRAY_IP=()
	ARRAY_SRV=()
	#Create base filesystem with dataset backing it
	while read -r LINE;
	do
		IP="$(echo $LINE | grep -E '(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9])[.]){3}(([2]([0-4][0-9]|[5][0-5])|[0-1]?[0-9]?[0-9]))' - | cut -d ' ' -f 5)"
		SRV="$(echo $LINE | grep -E 'open' | cut -d ' ' -f 3)"
		declare FILE
		if [[ -n "$IP" ]]
		then
			FILE="$TEMP/$TEMP_RAND/$IP"
			touch $FILE
			let IP_COUNT++
		else
			let SERVICE_COUNT++
		fi
		if [[ -n "$IP" ]]
		then
			ARRAY_IP[$IP_COUNT]="$IP"
		elif [[ -n "$SRV" ]]
		then
			echo "$SRV" >> "$FILE"
			ARRAY_SRV[$SERVICE_COUNT]="$SRV"
		fi
	done <<< "$DATASET"
	#Dedupe services in ip files
	for IP in "${ARRAY_IP[@]}"
	do
		SORTED_SRV="$(sort -u "$TEMP/$TEMP_RAND/$IP")" 
		$(echo "$SORTED_SRV" | tee "$TEMP/$TEMP_RAND/$IP" >/dev/null)
	done
	#Dedupe services into a final list of available services
	$(printf "%s\n" "${ARRAY_SRV[@]}" | sort -u | cat > $TEMP/$TEMP_RAND/services)
	#Iterate over services and create service files containing associated ips
	IFS=$'\n'
	while read -r SRV
	do
		touch $TEMP/$TEMP_RAND/$SRV
		for FILE in "${ARRAY_IP[@]}"
		do
			IS_SERV_IN_FILE="$(cat $TEMP/$TEMP_RAND/$FILE | grep -w "^$SRV\$")"
			if [[ -n $IS_SERV_IN_FILE ]]
			then
				echo "$FILE" | cat >> "$TEMP/$TEMP_RAND/$SRV"
				continue
			fi
		done
	done <<< "$(cat $TEMP/$TEMP_RAND/services)"
}

#Create output, what more is there to say?
create_output() {
	IP_COUNT=0
	while read -r SRV
	do
		while read -r IP
		do
			let IP_COUNT++
		done <<< "$(cat "$TEMP/$TEMP_RAND/$SRV")"
		echo_service "Service: $SRV Count: $IP_COUNT"
		echo_info "==============================="
		while read -r IP
		do
			echo_ip $IP
		done <<< "$(cat "$TEMP/$TEMP_RAND/$SRV")"
		IP_COUNT=0
		echo_info
	done <<< "$(cat "$TEMP/$TEMP_RAND/services")"
}

#Remove the bloat
remove_temp() {
	rm -rf "$TEMP/$TEMP_RAND"
}

#Execute all the things
check_args
create_temp
create_dataset
create_output
remove_temp
