#!/bin/bash

THIS_PROCESS=$BASHPID
TAG="aggregator.make_squint"
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

SQUINT_COMMAND="/usr/local/bin/squint.pl"
SQUINT="";
SQUINT+=${SQUINT_COMMAND};
SQUINT+=" --nodns " ;
ACCESS_LOG_DIR=${CACHE}/${ACCESS_LOG_SUB_FOLDER}

SET_DATE()
{
	TS=`date "+%Y-%m-%d"`
	[ "x$1" == "x" ] && return;
	D=$1 ; 
	TS=`date --date="$D" "+%F"`
}

# Month calculation
#  D=`date --date="$(date +%Y-%m-01) -0 day" "+%Y-%m-%d"` ; echo $D ; M=`date --date="$D +1 month" "+%Y-%m-%d"`; echo $M ; LD=`date --date="$M -1 day" "+%Y-%m-%d"`; echo $LD

MONTHLY_REPORT()
{
	SRV=$1
	local AXLOG="${ACCESS_LOG_DIR}/${SRV}/*.log"

	SD="";
	ED="";
	
	SD=`date --date="$TS" "+%Y-%m-01"`
	NM=`date --date="$SD +1 month" "+%F"`; 
	
	TITLE='<a href=".."><i>Back</i></a><br/>';
	TITLE+="Monthly Squint Reports for ${_SRV}";
	
	FN=`find ${AXLOG} -type f -newermt "${SD}" ! -newermt "${NM}" -size +0 | wc -l`
	[ ${FN} -eq 0 ] && return;
	
	PARENT=`date --date="${SD}" +"%Y"`
	FOLDER=`date --date="${SD}" +"%B"`

	REPORT_FOLDER="${WWW}/${SRV}/squint/${PARENT}/${FOLDER}"
	mkdir -p "${REPORT_FOLDER}"

	cat<<- _EOF
	find ${AXLOG} -type f -newermt "${SD}" ! -newermt "${NM}" -exec cat {} \; | ${SQUINT_COMMAND} --nodns "${REPORT_FOLDER}"  `date --date="${SD}" "+%s"` `date --date="${NM}" "+%s"`
	_EOF

	find ${AXLOG} -type f -newermt "${SD}" ! -newermt "${NM}" -exec cat {} \; | ${SQUINT_COMMAND} --nodns "${REPORT_FOLDER}"  `date --date="${SD}" "+%s"` `date --date="${NM}" "+%s"`

	tree  --sort=mtime -L 1 -afd "${WWW}/${SRV}/squint/${PARENT}" --noreport -H "."  -T "${TITLE}" > "${WWW}/${SRV}/squint/${PARENT}/index.html"
}

SERVER_REPORT()
{
	local _SRV="${1}"
	mkdir -p ${WWW}/${_SRV}/squint
	MONTHLY_REPORT ${_SRV}
}

DO_REPORTS()
{
	s=${#SERVERS[@]}
	for (( i=0; i<s; i++))
	do
		SERVER_REPORT "${SERVERS[$i]}"
		_SRV="${SERVERS[$i]}"
	done
	wait
}

MAIN()
{
	SET_DATE "$1"
	GET_V_SERVER
	GET_SERVERS
	DO_REPORTS
}

MAIN "$1"