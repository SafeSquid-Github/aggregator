#!/bin/bash
# called by _USER_ to perform the necessary updation
# perform the process of updating the files in the safesquid folder
# ACTION(s) performed : softlink, mkdir, copy with overwite, copy without overwrite
# OWNERSHIP and PERMISSIONS will also be set
THIS_PROCESS=$BASHPID
TAG="aggregator.setup"
NOW=`date +"%Y%m%d%H%M%S"`
if [[ -t 1 ]]; then
    exec 1> >( exec logger --id=${THIS_PROCESS} -s -t "${TAG}" ) 2>&1
else
    exec 1> >( exec logger --id=${THIS_PROCESS} -t "${TAG}" ) 2>&1
fi

set -o pipefail

CWD=`dirname $0`
IAM=`basename $0`
DATE=`date +"%F-%H-%M-%S"`
PARENT_DIR=`dirname ${CWD}`
TARGET_DIR="/opt/aggregator"

RSYNC_COMMAND="/usr/bin/rsync"
RRSYNC="/usr/local/bin/rrsync"

SYNC_USER="root"
SSH_KEY="id_rsa"
KEY_STORE="/root/.ssh"
WWW="/var/www/aggregator"

[ -f "/opt/aggregator/setup.ini" ] && . /opt/aggregator/setup.ini
[ "x${CWD}" == "x." ] && CWD=`pwd`
LOGFILE="/var/log/aggregator-setup-${DATE}.log"
OUR_IP=`ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

PACKAGES=();
PACKAGES+=("monit");
PACKAGES+=("net-tools");
PACKAGES+=("libgeoip-dev");
PACKAGES+=("libgeoip1");
PACKAGES+=("geoip-database");
PACKAGES+=("libmaxminddb-dev");
PACKAGES+=("zlib1g");
PACKAGES+=("mmdb-bin");
PACKAGES+=("openssh-client");
PACKAGES+=("rsync");
PACKAGES+=("bc");
PACKAGES+=("perl");
PACKAGES+=("libgd3");
PACKAGES+=("fonts-dejavu-core")
PACKAGES+=("fonts-freefont-ttf")
PACKAGES+=("apache2");
PACKAGES+=("libgd-graph-perl")
PACKAGES+=("libnet-xwhois-perl")
PACKAGES+=("libnet-dns-perl")
PACKAGES+=("libgeo-ipfree-perl")
PACKAGES+=("liburi-perl")
PACKAGES+=("libnet-ip-perl")
PACKAGES+=("libnetaddr-ip-perl");
PACKAGES+=("sarg");
PACKAGES+=("calamaris")
PACKAGES+=("webalizer");
PACKAGES+=("lightsquid")
PACKAGES+=("squidview")	
PACKAGES+=("awstats")
#PACKAGES+=("goaccess")

CUSTOM_PACKAGES_URL="https://downloads.safesquid.com/aggregator/custom"
GO_ACCESS="goaccess.deb"
SQUINT_PL="squint.deb"

RSYNC=();		
RSYNC+=(${RSYNC_COMMAND})
RSYNC+=("-r")
RSYNC+=("--times")
RSYNC+=("--verbose")
RSYNC+=("--archive")

COPY_FILES() 
{
	[ ! -d ${TARGET_DIR} ] && mkdir -pv ${TARGET_DIR} 
	${RSYNC[*]} ${PARENT_DIR}/opt/aggregator/* ${TARGET_DIR}/ 
	${RSYNC[*]} ${PARENT_DIR}/usr/local/* /usr/local/  
	[ -f ${TARGET_DIR}/servers.list ] && echo "already exists: ${TARGET_DIR}/servers.list"	
	[ ! -f ${TARGET_DIR}/servers.list ] && echo "# list of IPs of SafeSquid Proxy Servers" > ${TARGET_DIR}/servers.list
}

INSTALL_PACKAGES()
{
	apt-get update -y  && apt-get upgrade -y 
	apt-get install -y ${PACKAGES[*]} 
}

RSYSLOG_CONFIG()
{
	for RSYSLOG_CONF in `find ${TARGET_DIR}/etc/rsyslog.d/* -type f`
	do
		ln -vfs ${RSYSLOG_CONF} /etc/rsyslog.d/ 
	done
	systemctl restart rsyslog  
}

APACHE_CONFIG()
{
	for APACHE_CONF in `find ${TARGET_DIR}/etc/apache2/* -type f`
	do
		ln -vfs ${APACHE_CONF} /etc/apache2/sites-available 
		a2ensite `basename ${APACHE_CONF}` 
	done
	systemctl reload apache2
}

GOACCESS_SETUP()
{
	curl -f --output /usr/local/src/${GO_ACCESS} ${CUSTOM_PACKAGES_URL}/${GO_ACCESS} 
	[ ! -f "/usr/local/src/${GO_ACCESS}" ] && echo "not found: /usr/local/src/${GO_ACCESS}" && return;
	dpkg -i /usr/local/src/${GO_ACCESS}  
}

SQUINT_SETUP()
{
	curl -f --output /usr/local/src/${SQUINT_PL} ${CUSTOM_PACKAGES_URL}/${SQUINT_PL} 
	[ ! -f "/usr/local/src/${SQUINT_PL}" ] && echo "not found: /usr/local/src/${SQUINT_PL}" && return;
	dpkg -i /usr/local/src/${SQUINT_PL} 
}

SHARE_AUTHORIZATION()
{
	local SRV=$1
	local AUTHORIZATION=
	
	[ ! -f "${KEY_STORE}/${SSH_KEY}.pub" ] && echo "not found: ${KEY_STORE}/${SSH_KEY}.pub" && return 1;
	[ ! -d "${WWW}/setup" ] && mkdir -pv "${WWW}/setup" 
	
	AUTHORIZATION="command="
	AUTHORIZATION+='"'
	AUTHORIZATION+="${RRSYNC} -ro /var/log/safesquid/extended/"
	AUTHORIZATION+='"'
	AUTHORIZATION+=' '
	AUTHORIZATION+=`<${KEY_STORE}/${SSH_KEY}.pub`
	cat <<- _EOF > "${WWW}/setup/authorized_keys" 
	# The following directive in /root/.ssh/authorized_keys of your SafeSquid proxy servers enables aggregator to sync log files
	${AUTHORIZATION}
	_EOF
}

GEN_SSH_KEY()
{
	[ "x${KEY_STORE}" == "x" ] && echo "undefined: KEY_STORE " && return;
	[ "x${SSH_KEY}" == "x" ] && echo "undefined: SSH_KEY"  && return;
	[ -f "${KEY_STORE}/${SSH_KEY}" ] && echo "already exists: ${KEY_STORE}/${SSH_KEY}" && return;
	[ ! -d "${KEY_STORE}" ] && mkdir -p "${KEY_STORE}"  ;
	ssh-keygen -t rsa -b 4096 -C "aggregator@${OUR_IP}" -f ${KEY_STORE}/${SSH_KEY} -N "" 
}

MONIT_PAM()
{
	[ -f /etc/pam.d/monit ] && echo "already exists: /etc/pam.d/monit" && return 0;
	cat <<- _EOF > /etc/pam.d/monit 
	# monit: auth account password session
	auth       sufficient     pam_securityserver.so
	auth       sufficient     pam_unix.so
	auth       required       pam_deny.so
	account    required       pam_permit.so
	_EOF
}

MONIT_SETUP()
{
	for MONIT_CONF in `find ${TARGET_DIR}/etc/monit/conf.d/*.monit -type f`
	do
		ln -vfs ${MONIT_CONF} /etc/monit/conf.d/ 
	done
	monit reload 
}

MAIN()
{
	INSTALL_PACKAGES
	GOACCESS_SETUP
	SQUINT_SETUP
	COPY_FILES
	RSYSLOG_CONFIG
	APACHE_CONFIG
	GEN_SSH_KEY
	SHARE_AUTHORIZATION
	MONIT_PAM
	MONIT_SETUP
}

MAIN
