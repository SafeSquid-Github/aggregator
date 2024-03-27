#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_goaccess"
NOW=`date +"%Y%m%d%H%M%S"`
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

[ ! -f "/opt/aggregator/setup.ini" ] && exit;
. /opt/aggregator/setup.ini

GOACCESS_COMMAND="/usr/local/bin/goaccess"
GOACCESS_CONF="/opt/aggregator/etc/goaccess/goaccess.conf"
GOACCESS_CACHE="${CACHE}/goaccess"
LOG="/var/log/goaccess.log"

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

PROCESS_RUNNING()
{
	local SRV=$1
	local PID_FILE="/var/run/${SRV}.goaccess.pid"
	[ ! -f ${PID_FILE} ] && return 1;
	
	local PID=`<${PID_FILE}`
	
	[ ! -f /proc/${PID}/exe ] && rm ${PID_FILE} && return 1;
	local EXE=`readlink -efnq /proc/${PID}/exe`
	
	[ "x${EXE}" != "x${GOACCESS_COMMAND}" ] && rm ${PID_FILE} && return 1;
	
	echo "${SRV}: already running" >> ${LOG}
	return 0;
}

MAKE_REPORT()
{
	local SRV=$1
	local PORT=$2
	local SD="";
	local ED="";
	local OUTPUT=();
	local LOG_FILE_REMOTE="${RSYSLOG_AGGREGATOR_DIRECTORY}/${SRV}/extended.log"	
	local LOG_FILE_LOCAL="${LOG_DIRECTORY}/${EXTENDED_LOG_SUB_FOLDER}/extended.log"

	local TITLE="SafeSquid RealTime ${SRV}"
	[ "x${SRV}" != "x${LOCAL_HOST}" ] && local LOG_FILE="${LOG_FILE_REMOTE}" && mkdir -p "${RSYSLOG_AGGREGATOR_DIRECTORY}/${SRV}"
	[ "x${SRV}" == "x${LOCAL_HOST}" ] && local LOG_FILE="${LOG_FILE_LOCAL}"
	
	local REPORT_FOLDER="${WWW}/${SRV}/goaccess"
	
	local FIFO_OUT="/tmp/${SRV}.goaccess.out"
	local FIFO_IN="/tmp/${SRV}.goaccess.in"
	local DB_PATH="${GOACCESS_CACHE}/${SRV}"
	local REPORT="${REPORT_FOLDER}/index.html"
	local DEBUG_FILE="/var/log/goaccess.${SRV}.log"
	local PID_FILE="/var/run/${SRV}.goaccess.pid"
	mkdir -p ${DB_PATH}
	mkdir -p "${REPORT_FOLDER}"
	
	[ -f ${FIFO_OUT} ] && rm ${FIFO_OUT}
	[ -f ${FIFO_IN} ] && rm ${FIFO_IN}
	
	OUTPUT=(--pid-file=${PID_FILE});
	OUTPUT+=(--real-time-html);
	OUTPUT+=(--no-global-config);
	OUTPUT+=(--hl-header);
	OUTPUT+=(--with-mouse);
	OUTPUT+=(--no-term-resolver);
	OUTPUT+=( --real-time-html);
	OUTPUT+=(--persist);
	OUTPUT+=(--4xx-to-unique-count);
	OUTPUT+=(--fifo-out=${FIFO_OUT});
	OUTPUT+=(--fifo-in=${FIFO_IN});
	OUTPUT+=(--port=${PORT});
	OUTPUT+=(--log-file=${LOG_FILE});
	OUTPUT+=(--config-file=${GOACCESS_CONF});
	OUTPUT+=(--db-path=${DB_PATH});
	OUTPUT+=(--output=${REPORT});
	OUTPUT+=(--debug-file=${DEBUG_FILE});
	OUTPUT+=(--max-items=500);
	OUTPUT+=(--daemonize);
	
	cat <<- _EOF >> ${LOG}
	${GOACCESS_COMMAND} ${OUTPUT[*]} --html-report-title="${TITLE}"
	_EOF

	${GOACCESS_COMMAND} ${OUTPUT[*]} --html-report-title="${TITLE}"
}

DO_REPORTS()
{
	GET_V_SERVER
	GET_SERVERS
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
	_SRV="${SERVERS[$i]}"
	PROCESS_RUNNING $_SRV && continue;

	P=$[ i + 7890 ]
	mkdir -p ${WWW}/${SERVERS[$i]}/goaccess
	MAKE_REPORT ${SERVERS[$i]} ${P}
	done	
}

MAIN()
{
	DO_REPORTS
}

MAIN "$1"
wait