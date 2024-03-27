#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_webalizer"
NOW=`date +"%Y%m%d%H%M%S"`
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

[ ! -f "/opt/aggregator/setup.ini" ] && exit;
. /opt/aggregator/setup.ini

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

WEBALIZER="/usr/bin/webalizer"
WEBALIZER_CONF="/opt/aggregator/etc/webalizer/webalizer.conf"
FLAGS="/opt/aggregator/etc/webalizer/flags"

SET_DATE()
{
	TS=`date +"%F"`
	[ "x$1" == "x" ] && return;
	D=$1 ; 
	TS=`date --date="$D" +"%F"`
}

# zcat -f /var/log/aggregator/safesquid/192.168.250.148/extended/20211213191921-extended.log.gz | tr -d '"' | awk -F'\t' '{print $11,"-",$12,"["$4"]","\""$13, $14,"HTTP/1.1\"",$6,$7,$15,"\""$16"\""}'

DAILY_REPORT()
{
	local SRV=$1
	local ARGS=();
	local EXLOG_REMOTE="${LOCAL_AGGREGATOR_DIRECTORY}/${SRV}/${EXTENDED_LOG_SUB_FOLDER}/*"
	local EXLOG_LOCAL="${LOG_DIRECTORY}/${EXTENDED_LOG_SUB_FOLDER}/*"
#EXTENDED_LOG_SUB_FOLDER

	echo "Making Daily Report"
	local REPORT_FOLDER="${WWW}/${SRV}/webalizer"
	local SD="";
	local ED="";
	local AXLOG="${CACHE}/${ACCESS_LOG_SUB_FOLDER}/${SRV}/*.log"
	[ "x${SRV}" == "x${LOCAL_HOST}"  ] && local EXLOG="${EXLOG_LOCAL}" || local EXLOG="${EXLOG_REMOTE}"
	local BW=`date --date="${TS}" +"%F"`; 
	local EW=`date --date="${TS} +1 days" +"%F"`; 
	FN=`find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 | wc -l`
	[ ${FN} -eq 0 ] && return;
	SD=`date --date="${BW}" +"%d/%m/%Y"`
	ED=`date --date="${BW}" +"%d/%m/%Y"`
	mkdir -p "${REPORT_FOLDER}"
	rsync --recursive ${FLAGS} "${REPORT_FOLDER}"
	ARGS+=('-F'); ARGS+=("clf")
	ARGS+=('-c'); ARGS+=("${WEBALIZER_CONF}")
	ARGS+=('-o'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('-n'); ARGS+=("${SRV}");
	ARGS+=('-d'); 
	ARGS+=('-v'); 
#	find ${EXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec zcat -f {} \; | tr -d '"' | awk -F'\t' '{host=$24} {if ($26 != "-") host=$26; } {print host,"\"-\"",$12,"["$4"]","\""$13, $14,"HTTP/1.1\"",$6,$7,$15,"\""$16"\""}' | ${WEBALIZER} -t "${SRV} Report" ${ARGS[@]} -
	find ${EXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec zcat -f {} \; | tr -d '"' | awk -F'\t' '{print $24,"\"-\"",$12,"["$4"]","\""$13, $14,"HTTP/1.1\"",$6,$7,$15,"\""$16"\""}' | ${WEBALIZER} ${ARGS[@]} -
#	find ${EXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec zcat -f {} \; | tr -d '"' | awk -F'\t' '{print $25,"-",$12,"["$4"]","\""$13, $14,"HTTP/1.1\"",$6,$7,$15,"\""$16"\""}' | ${WEBALIZER} -t "${SRV} Report" ${ARGS[@]} -
#	find ${EXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec zcat -f {} \; | tr -d '"' | awk -F'\t' '{print $11,"-",$12,"["$4"]","\""$13, $14,"HTTP/1.1\"",$6,$7,$15,"\""$16"\""}' | ${WEBALIZER} -t "${SRV} Report" ${ARGS[@]} -
	return;
}

SERVER_REPORT()
{
	local _SRV="${1}"
	mkdir -p ${WWW}/${_SRV}/webalizer
	DAILY_REPORT ${_SRV}
}

DO_REPORTS()
{
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		SERVER_REPORT "${SERVERS[$i]}"
	done
	wait
}

MAIN()
{
	date
	GET_V_SERVER
	GET_SERVERS
	SET_DATE "$1"
	DO_REPORTS
}

MAIN "$1"