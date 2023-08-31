#!/bin/bash

mkdir /run/lock

echo "Setting ServerName"
echo "ServerName ${HOSTNAME}.${DOMAINNAME}" >> /etc/apache2/apache2.conf

echo "Creating Directories"
MRTGDIR=${MRTGDIR:-"/etc/mrtg"}
#WEBDIR=${WEBDIR:-"/mrtg/html"}
WEBDIR=${WEBDIR:-"/var/www/html"}
MRTGCFG=/etc/mrtg.cfg

[[ ! -d "${MRTGDIR}" ]] && mkdir -p ${MRTGDIR}
[[ ! -d "${WEBDIR}" ]] && mkdir -p ${WEBDIR}

echo "Looping through targets and creating cfg files"
if [ -n "${HOSTS}" ]; then
    hosts=$(echo ${HOSTS} | tr '[,;]' ' ')
    for asset in ${hosts}; do
        read -r COMMUNITY HOST VERSION PORT < <(echo ${asset} | sed -e 's/:/ /g')

        if [[ "${VERSION}" -eq "2" || -z "${VERSION}" ]]; then _snmp_ver="2c"; else _snmp_ver=${VERSION}; fi
        # NAME=$(snmpwalk -Oqv -v${_snmp_ver} -c ${COMMUNITY} ${HOST}:${PORT:-"161"} .1.3.6.1.2.1.1.5)
        NAME=${HOST}
        NAME_LOWER=$(echo $NAME | tr '[:upper:]' '[:lower:]')
        NAME_UPPER=$(echo $NAME | tr '[:lower:]' '[:upper:]')
        echo "Target -> $NAME"
        # if [ -z "${NAME}" ]; then
        #     NAME=${HOST}
        #     echo "Setting Name=$HOST"
        # fi
        [[ ! -f "${MRTGDIR}/conf.d/${NAME_UPPER}.cfg" ]] && /usr/bin/cfgmaker \
            --ifref=name \
            --global "WorkDir: $WEBDIR" \
            --global "Options[_]: growright, bits" \
            --subdirs=${NAME_UPPER} \
            --no-down \
            --show-op-down \
            --snmp-options=:${PORT:-"161"}::::${VERSION:-"2"} \
            --output=${MRTGDIR}/conf.d/${NAME_UPPER}.cfg "${COMMUNITY}@${HOST}"
    done
else
    COMMUNITY=${1:-"public"}
    HOST=${2:-"localhost"}
    VERSION=${3:-"2"}
    PORT=${4:-"161"}
    if [[ "${VERSION}" -eq "2" || -z "${VERSION}" ]]; then _snmp_ver="2c"; else _snmp_ver=${VERSION}; fi
    NAME=$(snmpwalk -Oqv -v${_snmp_ver} -c ${COMMUNITY} ${HOST}:${PORT} .1.3.6.1.2.1.1.5)
    if [ -z "${NAME}" ]; then
        NAME="${HOST}"
    fi
    [[ ! -f "${MRTGDIR}/conf.d/${NAME}.cfg" ]] && /usr/bin/cfgmaker \
            --ifref=name \
            --global "Options[_]: growright, bits" \
            --global "EnableIPv6: ${ENABLE_V6}" \
            --snmp-options=:${PORT}::::${VERSION} \
            --output=${MRTGDIR}/conf.d/${NAME}.cfg "${COMMUNITY}@${HOST}"
fi

echo "Starting webserver"
service apache2 start
# ln -s /mrtg/html /var/www/mrtg
ln -s /var/www/html /var/www/mrtg 
# cfgmaker ${SNMP_COMMUNITY}@${SNMP_HOST} > /tmp/mrtg.cfg
# cat /tmp/mrtg.cfg | sed 's/#\ Options\[_\]/Options\[_\]/' > /etc/mrtg.cfg

echo "#Global configuration" > ${MRTGCFG}
echo "WorkDir: $WEBDIR" >> ${MRTGCFG}
echo "Refresh: 600" >> ${MRTGCFG}
echo "WriteExpires: Yes" >> ${MRTGCFG}
echo "PathAdd: /usr/bin" >> ${MRTGCFG}
echo "" >> ${MRTGCFG}
echo "Title[^]: Traffic Analysis for" >> ${MRTGCFG}
echo "Options[_]: growright,bits" >> ${MRTGCFG}
# echo "Include: ${MRTGDIR}/conf.d/*.cfg" >> ${MRTGCFG}

# cp /etc/mrtg.tmp /etc/mrtg.cfg

echo "Starting mrtg"
/usr/bin/mrtg
sleep 2

# echo "Creating all.html file"
# /usr/bin/indexmaker --output ${WEBDIR}/all.html --columns=3 ${MRTGCFG}
# sleep 2

# echo "Starting mrtg"
# /usr/bin/mrtg

echo "Creating index files"
if [ -n "${HOSTS}" ]; then
    for asset in ${hosts}; do
        read -r COMMUNITY HOST VERSION PORT < <(echo ${asset} | sed -e 's/:/ /g')
        NAME=${HOST}
        NAME_LOWER=$(echo $NAME | tr '[:upper:]' '[:lower:]')
        NAME_UPPER=$(echo $NAME | tr '[:lower:]' '[:upper:]')
        echo "Indexing $NAME_UPPER"
        echo "" >> ${MRTGCFG}
        cat ${MRTGDIR}/conf.d/$NAME_UPPER.cfg >> ${MRTGCFG}
        /usr/bin/indexmaker --output ${WEBDIR}/${NAME_UPPER}.html --columns=3 --filter name=~${NAME_LOWER} --title="${NAME} Interface Statistics" ${MRTGCFG}
        sleep 2
    done
fi

echo "Creating all.html file"
/usr/bin/indexmaker --output ${WEBDIR}/all.html --columns=3 ${MRTGCFG}
sleep 2

indexmaker /etc/mrtg.cfg > /var/www/html/index.html

echo "Start polling cycle"

while (true); do /usr/bin/mrtg; sleep 300; echo "Polling Targets"; done
