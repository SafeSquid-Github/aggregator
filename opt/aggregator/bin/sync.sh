#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.sync"
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

[ ! -f "/opt/aggregator/setup.ini" ] && exit;
source /opt/aggregator/setup.ini

SERVERS=();
V_SERVERS=();

GET_SERVERS()
{
	local COMMENT="#*"
	while read -r SNAME
	do
		SERVERS+=(${SNAME%%${COMMENT}})
	done < "${SERVERS_LIST}"	
}

GET_V_SERVER()
{
	local V_SERVER_STRING="#VIP*"
	local COMMENT="#VIP_"
	while read -r VNAME
	do
		[[ $VNAME == $V_SERVER_STRING ]] && V_SERVERS+=${VNAME#$COMMENT}
	done < "${SERVERS_LIST}"

}

RSYNC_COMMAND="/usr/bin/rsync"
# LOG_CONVERTOR="/usr/local/bin/log_convert"
LOG="/var/log/sync.log"
# NEW_LOG="N"

CHECK_FOLDERS()
{
	[ "x${LOCAL_AGGREGATOR_DIRECTORY}" == "x" ] && echo "error: unspecified: LOCAL_AGGREGATOR_DIRECTORY" && exit 1
	[ ! -d "${LOCAL_AGGREGATOR_DIRECTORY}" ] && mkdir -p "${LOCAL_AGGREGATOR_DIRECTORY}"
	[ ! -d "${LOCAL_AGGREGATOR_DIRECTORY}" ] && echo "error: creating: LOCAL_AGGREGATOR_DIRECTORY: ${LOCAL_AGGREGATOR_DIRECTORY}" && exit 1
}

START_SYNC()
{
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		local RSYNC=();
		local SOURCE=${SERVERS[$i]}
		[ "x${SOURCE}" == "x${LOCAL_HOST}" ] && echo "info: log_file: Use local log files" && continue
		local DEST="${LOCAL_AGGREGATOR_DIRECTORY}/${SOURCE}/${EXTENDED_LOG_SUB_FOLDER}/"

		[ ! -d "${DEST}" ] && mkdir -p "${DEST}"
		[ ! -d "${DEST}" ] && echo "failed to create: ${DEST}" && continue;
		mkdir -p "${LOCAL_AGGREGATOR_DIRECTORY}/${SOURCE}/${ACCESS_LOG_SUB_FOLDER}"
		
		RSYNC+=("${RSYNC_COMMAND}")
		RSYNC+=("--append")
		RSYNC+=("--compress")
		RSYNC+=("--times")
		RSYNC+=("--archive")
		RSYNC+=("--recursive")
		RSYNC+=("--no-links")
		RSYNC+=("--info=FLIST")
		RSYNC+=("--include=*extended.log")
		RSYNC+=("--log-file=${DEST}/.journal")
		RSYNC+=("--verbose")
		cat <<- _EOF
		${RSYNC[*]} -e "ssh -i ${KEY_STORE}/${SSH_KEY}" ${SYNC_USER}@${SOURCE}:${REMOTE_LOG_DIRECTORY} "${DEST}"
		_EOF
		"${RSYNC[@]}" -e "ssh -i ${KEY_STORE}/${SSH_KEY}" "${SYNC_USER}@${SOURCE}":"${REMOTE_LOG_DIRECTORY}" "${DEST}"
		
		echo "RSYNC: $SOURCE: $?"
	done
}

START_V_SYNC()
{
	v=${#V_SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		local RSYNC=();
		local DEST="${LOCAL_AGGREGATOR_DIRECTORY}/${V_SERVERS[$i]}"

		[ ! -d "${DEST}" ] && mkdir -p "${DEST}"
		[ ! -d "${DEST}" ] && echo "failed to create: ${DEST}" && continue;
		s=${#SERVERS[@]}
		for (( i=0; i<s; i++))
		do
			local SRV=${SERVERS[$i]}
			local SOURCE="${LOCAL_AGGREGATOR_DIRECTORY}/${SRV}/${EXTENDED_LOG_SUB_FOLDER}"
				
			RSYNC+=("${RSYNC_COMMAND}")
			RSYNC+=("--append")
			RSYNC+=("--compress")
			RSYNC+=("--times")
			RSYNC+=("--archive")
			RSYNC+=("--recursive")
			RSYNC+=("--no-links")
			RSYNC+=("--info=FLIST")
			RSYNC+=("--include=*extended.log")
			RSYNC+=("--log-file=${DEST}/.journal")
			RSYNC+=("--verbose")
			cat <<- _EOF
			${RSYNC[*]} ${SOURCE}/* ${DEST}/"
			_EOF
			"${RSYNC[@]}" ${SOURCE}/* "${DEST}/"
			
			echo "RSYNC: $SOURCE: $?"
		done
	done
}

MAIN()
{
	date >> ${LOG}
	GET_SERVERS
	GET_V_SERVER
	CHECK_FOLDERS
	START_SYNC
	START_V_SYNC
}

MAIN
# rsync --append -zta --no-links -vze ssh root@192.168.250.148:/var/log/safesquid/extended/ /home/nonsense/