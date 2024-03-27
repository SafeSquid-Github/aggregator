#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_calamaris"
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

CALAMARIS_COMMAND="/usr/bin/calamaris"
CALAMARIS_CONF="/opt/aggregator/etc/calamaris/calamaris.conf"
CALAMARIS_CACHE="${CACHE}/calamaris"
CALAMARIS_CSS="/opt/aggregator/etc/calamaris/calamaris.css"

ACCESS_LOG_DIR=${CACHE}/${ACCESS_LOG_SUB_FOLDER}

SET_DATE()
{
	TS=`date "+%Y-%m-%d"`

	[ "x$1" == "x" ] && return;
	D=$1 ; 
	TS=`date --date="$D" "+%F"`
}


MONTHLY_REPORT()
{
	local SRV=$1
	echo "Making Monthly Report"
	local FOLDER=`date --date="${TS}" +"%Y/%B"`
	local REPORT_FOLDER="${WWW}/${SRV}/calamaris/${FOLDER}"
	local ARGS=();
	local CACHES=();
	local CACHE_IN="";

	local BW=`date --date="${TS}" +"%Y-%m-01"`; 
	local EW=`date --date="${BW} +1 month" +"%F"`; 

	local REPORT_NAME="SafeSquid Monthly Report for ${FOLDER}</BR>${BW} to ${TS}"
	
	for cacheF in `find ${CALAMARIS_CACHE}/${SRV}/*.cache -type f -newermt "${BW}" ! -newermt "${EW}" -size +0`
	do
		CACHES+=(${cacheF})
	done

	_IFS="${IFS}"; IFS=':' ;  CACHE_IN="${CACHES[*]}";  IFS="${_IFS}" ; 
	
	[ "x${CACHE_IN}" == "x" ] && echo "no cache for ${REPORT_NAME}" && return;
	
	mkdir -p "${REPORT_FOLDER}"

	ARGS+=('--config-file'); ARGS+=("${CALAMARIS_CONF}")
	ARGS+=('--no-input'); 
	if [  "x${CACHE_IN}" != "x" ]
	then
		ARGS+=('--cache-input-file');
		ARGS+=("${CACHE_IN}")
	fi
	ARGS+=('--output-path'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('--output-file'); ARGS+=("index.html");
	ARGS+=('--meta'); ARGS+=("${CALAMARIS_CSS}");
	
	${CALAMARIS_COMMAND} "${ARGS[@]}" -H "${REPORT_NAME}"
		
	return;
}

WEEKLY_REPORT()
{
	local SRV=$1
	echo "Making Weekly Report"
	local D=`date --date="${TS}" +"%-d"`
	local WK=$[ D / 7 ]
	local FOLDER=`date --date="${TS}" +"%Y/%B/week-${WK}"`
	local REPORT_FOLDER="${WWW}/${SRV}/calamaris/${FOLDER}"
	
	local ARGS=();
	local CACHES=();
	local CACHE_IN="";

	local W=`date --date="${TS}" +"%w"`; 	
	local BW=`date --date="${TS} -${W} days" +"%F"`; 	
	local EW=`date --date="${BW} +1 week" +"%F"`; 

	local REPORT_NAME="SafeSquid Weekly Report for ${FOLDER} </BR>${BW} to ${TS}"
	
	for cacheF in `find ${CALAMARIS_CACHE}/${SRV}/*.cache -type f -newermt "${BW}" ! -newermt "${EW}" -size +0`
	do
		echo "cacheF: ${cacheF}"
		CACHES+=(${cacheF})
	done

	_IFS="${IFS}"; IFS=':' ;  CACHE_IN="${CACHES[*]}";  IFS="${_IFS}" ; 
	
	[ "x${CACHE_IN}" == "x" ] && echo "no cache for ${REPORT_NAME}" && return;
	
	mkdir -p "${REPORT_FOLDER}"

	ARGS+=('--config-file'); ARGS+=("${CALAMARIS_CONF}")
	ARGS+=('--no-input'); 
	if [  "x${CACHE_IN}" != "x" ]
	then
		ARGS+=('--cache-input-file');
		ARGS+=("${CACHE_IN}")
	fi
	ARGS+=('--output-path'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('--output-file'); ARGS+=("index.html");
	ARGS+=('--meta'); ARGS+=("${CALAMARIS_CSS}");
	
	cat<<- _EOF
	${CALAMARIS_COMMAND} ${ARGS[@]} -H "${REPORT_NAME}"
	_EOF
	
	${CALAMARIS_COMMAND} "${ARGS[@]}" -H "${REPORT_NAME}"
		
	return;
}

DAILY_REPORT()
{
	local SRV=$1
	echo "Making Daily Report"
	
	local AXLOG="${ACCESS_LOG_DIR}/${SRV}/*.log"
	[ "x${2}" == "x*" ] && AXLOG="${ACCESS_LOG_DIR}/*/*.log"

	local W=`date --date="${TS}" +"%w"`
	local D=`date --date="${TS}" +"%-d"`
	local WK=$[ D / 7 ]
	local BW=${TS}
	local EW=`date --date="${TS} +1 days" +"%F"`
	local FOLDER=`date --date="${TS}" +"%Y/%B/week-${WK}/%F"`
	local REPORT_FOLDER="${WWW}/${SRV}/calamaris/${FOLDER}"
	local ARGS=();
	
	local SD=`date --date="${BW}" +"%Y%m%d000000"`
	local ED=`date --date="${EW}" +"%Y%m%d000000"`

	local FN=`find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 | wc -l`
	[ ${FN} -eq 0 ] && return;
	
	mkdir -p "${REPORT_FOLDER}"
	
	local REPORT_NAME="SafeSquid Daily Report for `date --date="${TS}" +"%A, %d %B %Y"`"
	
	local CACHE_OUT=${CALAMARIS_CACHE}/${SRV}/
	mkdir -p ${CACHE_OUT}
	CACHE_OUT+="`date --date="${TS}" "+%Y.%m.%d.cache"`"

	ARGS+=('--config-file'); ARGS+=("${CALAMARIS_CONF}")
	ARGS+=('--time-interval'); ARGS+=("${SD}-${ED}")
	ARGS+=('--cache-output-file'); ARGS+=("${CACHE_OUT}")
	ARGS+=('--output-path'); ARGS+=("${REPORT_FOLDER}");
	ARGS+=('--output-file'); ARGS+=("index.html");
	ARGS+=('--meta'); ARGS+=("${CALAMARIS_CSS}");

	cat<<- _EOF
	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${CALAMARIS_COMMAND} ${ARGS[@]} -H "${REPORT_NAME}"
	_EOF


	find ${AXLOG} -type f -newermt "${BW}" ! -newermt "${EW}" -size +0 -exec cat {} \; | ${CALAMARIS_COMMAND} "${ARGS[@]}" -H "${REPORT_NAME}"
	cat <<- _EOF
	[ -f ${CACHE_OUT} ] && touch -c --date="${BW}" ${CACHE_OUT}
	_EOF
	
	[ -f ${CACHE_OUT} ] && touch -c --date="${BW}" ${CACHE_OUT}
	
	return;
	
}

SERVER_REPORT()
{
	local _SRV="${1}"	
	mkdir -p ${WWW}/${_SRV}/calamaris
	DAILY_REPORT ${_SRV} "${2}"
	WEEKLY_REPORT ${_SRV} "${2}"
	MONTHLY_REPORT ${_SRV} "${2}"
	echo "created report for ${_SRV}"

	find "${WWW}/${_SRV}/calamaris/" -empty -type d -delete
	find "${CALAMARIS_CACHE}/${_SRV}/" -empty -type d -delete

	tree -afd "${WWW}/${_SRV}/calamaris/" --noreport -H .  -T "Reports for ${_SRV}" > "${WWW}/${_SRV}/calamaris/index.html"
	[ -f "${WWW}/${_SRV}/calamaris/index.html" ] && echo "created ${WWW}/${_SRV}/calamaris/index.html"
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
#	GET_V_SERVER
	GET_SERVERS
	SET_DATE "$1"
	DO_REPORTS
}

MAIN "$1"

# D="2021-12-13"; for (( i=0; i < 300 ; i++)); do  X=`date --date="$D +$i days" +"%F"`; ./make_calamaris.sh "$X"; done

