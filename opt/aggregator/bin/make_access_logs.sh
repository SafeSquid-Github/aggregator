#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_access_log"
NOW=`date +"%Y%m%d%H%M%S"`
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

[ ! -f "/opt/aggregator/setup.ini" ] && exit;
. /opt/aggregator/setup.ini


RSYNC_COMMAND="/usr/bin/rsync"
LOG_CONVERTOR="/usr/local/bin/log_convert"

LOG="/var/log/convert.log"
NEW_LOG="N"
ACCESS_LOG_DIR=${CACHE}/${ACCESS_LOG_SUB_FOLDER}
declare -A SERVER_UPDATED=();

SERVERS=();

GET_V_SERVER()
{
	local V_SERVER_STRING="#VIP*"
	local COMMENT="#VIP_"
	while read -r VNAME
	do
		[[ $VNAME == $V_SERVER_STRING ]] && SERVERS+=${VNAME#$COMMENT}
	done < "${SERVERS_LIST}"
}

GET_SERVERS()
{
	local COMMENT="#*"
	while read SNAME
	do
		SERVERS+=(${SNAME%%${COMMENT}})
	done < ${SERVERS_LIST}	
}

SET_SD()
{
	local TS
	TS=`date --date="@${1}" +"%F"`;
	local BD=`date --date="${TS} +0 day" +"%s"`;
	echo ${BD}
}


PARSE_LOG()
{
	local SD ED FD DD
	let SD=0;
	let ED=0;
	local SRV=$2
	local DEST=${ACCESS_LOG_DIR}/${SRV}
	FD="";
	while IFS=' ' read -s DD
	do 	
		[ "x${DD}" == "x" ] && continue;
		let X=${DD%% *}
		[ "x$X" == "x" ] && continue;
		[[ $X -gt $ED ]] && {
			let SD=`SET_SD $X`
			let ED=$[ SD + 86400 - 1 ]
			FD=`date --date="@${SD}" +"%F"`
		}
		
		echo ${DD} >> ${DEST}/${FD}.log
		
	done  < $1
}

CONVERT()
{
	declare -A JOURNAL=();
	local SRV=$1
	FROM_REMOTE=${LOCAL_AGGREGATOR_DIRECTORY}/${SRV}/${EXTENDED_LOG_SUB_FOLDER}
	FROM_LOCAL=${LOG_DIRECTORY}/${EXTENDED_LOG_SUB_FOLDER}
	[ "x${SRV}" != "x${LOCAL_HOST}"  ] && local FROM=${FROM_REMOTE} || local FROM=${FROM_LOCAL}
	local DEST=${ACCESS_LOG_DIR}/${SRV} 
	local JOURNAL_FILE=${ACCESS_LOG_DIR}/${SRV}/journal
	local TMP_LOG=`mktemp`

	[ ! -d ${DEST} ] && mkdir -p "${DEST}"
	[ ! -d ${DEST} ] && echo "failed to create: ${DEST}" && return;
		
	[ -f ${JOURNAL_FILE} ] && while read -ra ENTRY
	do
#		JOURNAL+=( [${ENTRY[0]}]="${ENTRY[1]}" );
		JOURNAL[${ENTRY[0]}]="${ENTRY[1]}"
	done <<< $(cat ${JOURNAL_FILE})
		
	find ${FROM}/*-extended.* -type f -printf "%Ts ${FROM} %f\n" | sort -n | while read TIMESTAMP SOURCE EXTLOG
	do
		[ "x${JOURNAL[${SOURCE}/${EXTLOG}]}" == "x${TIMESTAMP}" ] && echo "skipping ${SOURCE}/${EXTLOG}" && continue;
		
		[ -f "${SOURCE}/${EXTLOG}.gz" ] && echo "skipping: ${SOURCE}/${EXTLOG} use ${SOURCE}/${EXTLOG}.gz" && continue;
		
		> ${TMP_LOG}
		zcat -f ${SOURCE}/${EXTLOG} | ${LOG_CONVERTOR} > ${TMP_LOG}
		PARSE_LOG ${TMP_LOG} ${SRV}
		echo -e "${SOURCE}/${EXTLOG}\t${TIMESTAMP}" >> ${JOURNAL_FILE}
	done
	
	rm ${TMP_LOG}
}

SORT()
{
	local SRV=$1
	local DEST=${ACCESS_LOG_DIR}/${SRV}
	
	
	find ${DEST}/*.log -type f -printf "%Ts %p %f\n" | while read TIMESTAMP FULL_PATH AXLOG
	do
		TS=`date --date=@${TIMESTAMP} +"%F"`
		FD=${AXLOG%%.*}
		RT=`date --date=${FD} +"%s"`
		[ "${TIMESTAMP}" != "${RT}" ] && SERVER_UPDATED[${SRV}]="${TS}"
		[ "x${AXLOG}" == "x${TS}.log" ] && continue;
		
		local TEMP=`mktemp`
		sort -us -o ${TEMP} ${FULL_PATH}
		cp ${TEMP} ${FULL_PATH}
		rm ${TEMP}
		touch -m --no-create --date="${FD}" ${FULL_PATH}
		SERVER_UPDATED[${SRV}]="${TS}"
		
	done
}

SET_TRIGGER()
{
	local TEMP=`mktemp`
	echo "${!SERVER_UPDATED[@]}" | tr -s ' ' '\n' > ${TEMP}
	cp ${TEMP} ${REPORT_TRIGGER}
}

MAIN()
{
	GET_V_SERVER
	GET_SERVERS
	declare -i s=${#SERVERS[@]}
	
	for (( i=0; i<s; i++))
	do
		local SRV=${SERVERS[$i]}
		local FROM=${LOCAL_AGGREGATOR_DIRECTORY}/${SRV}/${EXTENDED_LOG_SUB_FOLDER}
		local DEST=${ACCESS_LOG_DIR}/${SRV}
		
		CONVERT ${SRV}
		SORT ${SRV}
	done
	
	SET_TRIGGER
}

MAIN
exit