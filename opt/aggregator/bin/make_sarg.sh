#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_sarg"
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

SARG="/usr/bin/sarg"
SARG_CONF="/opt/aggregator/etc/sarg/sarg.conf"
ACCESS_LOG_DIR=${CACHE}/${ACCESS_LOG_SUB_FOLDER}

SET_DATE()
{
	TS=`date +"%F"`
	[ "x$1" == "x" ] && return;
	D=$1 ; 
	TS=`date --date="$D" +"%F"`
}


WEEKLY_REPORT()
{
	local SRV=$1
	local ARGS=();

	echo "Making Weekly Report"
	local REPORT_FOLDER="${WWW}/${SRV}/sarg/weekly"
	local W=`date --date="${TS}" +"%w"`;
	local SD="";
	local ED="";
	local AXLOG="${ACCESS_LOG_DIR}/${SRV}/*.log"

	[ "x${2}" == "x*" ] && AXLOG="${ACCESS_LOG_DIR}/*/*.log"

	local BW=`date --date="${TS} -${W} days" +"%F"`; 
	local EW=`date --date="${BW} +6 days" +"%F"`; 

	local FN=`find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 | wc -l`
	[ ${FN} -eq 0 ] && return;

	SD=`date --date="${BW}" +"%d/%m/%Y"`
	ED=`date --date="${EW}" +"%d/%m/%Y"`

	mkdir -p "${REPORT_FOLDER}"

	ARGS+=('-c'); ARGS+=("${SARG_CONF}")
	ARGS+=('-d'); ARGS+=("${SD}-${ED}")
	ARGS+=('-o'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('--keeplogs');
	ARGS+=('-l'); ARGS+=('-');
	cat <<- _EOF
	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${SARG} ${ARGS[@]}
	_EOF
	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${SARG} ${ARGS[@]}

}

DAILY_REPORT()
{
	local SRV=$1
	local ARGS=();

	echo "Making Daily Report"
	local REPORT_FOLDER="${WWW}/${SRV}/sarg/daily"
	local SD="";
	local ED="";
	local AXLOG="${ACCESS_LOG_DIR}/${SRV}/*.log"

	[ "x${2}" == "x*" ] && AXLOG="${ACCESS_LOG_DIR}/*/*.log"


	local BW=`date --date="${TS}" +"%F"`; 
	local EW=`date --date="${TS} +1 days" +"%F"`; 

	FN=`find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 | wc -l`
	[ ${FN} -eq 0 ] && return;

	SD=`date --date="${BW}" +"%d/%m/%Y"`
	ED=`date --date="${BW}" +"%d/%m/%Y"`
	
	mkdir -p "${REPORT_FOLDER}"

	ARGS+=('-c'); ARGS+=("${SARG_CONF}")
	ARGS+=('-d'); ARGS+=("${SD}-${ED}")
	ARGS+=('-o'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('--keeplogs');
	ARGS+=('-l'); ARGS+=('-');

	cat <<- _EOF
	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${SARG} ${ARGS[@]}
	_EOF
	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${SARG} ${ARGS[@]}

}

SERVER_REPORT()
{
	local _SRV="${1}"
	mkdir -p ${WWW}/${_SRV}/sarg
	DAILY_REPORT ${_SRV} "$2"
	WEEKLY_REPORT ${_SRV} "$2"
}


DO_REPORTS()
{
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		SERVER_REPORT "${SERVERS[$i]}"
	done
	
	[ "x${CLUSTER_ID}" != "x" ] && SERVER_REPORT "${CLUSTER_ID}" "*"
	wait
}

MAIN()
{
	date
	# GET_V_SERVER
	GET_SERVERS
	SET_DATE "$1"
	DO_REPORTS
}

MAIN "$1"