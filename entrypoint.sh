#!/bin/bash

mkdir /run/lock

echo "Setting ServerName"
echo "ServerName ${HOSTNAME}.${DOMAINNAME}" >> /etc/apache2/apache2.conf

echo "Creating Directories"
MRTGDIR=${MRTGDIR:-"/etc/mrtg"}
WEBDIR=${WEBDIR:-"/mrtg/html"}
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
        echo "Target -> $NAME"
        # if [ -z "${NAME}" ]; then
        #     NAME=${HOST}
        #     echo "Setting Name=$HOST"
        # fi
        [[ ! -f "${MRTGDIR}/conf.d/${NAME}.cfg" ]] && /usr/bin/cfgmaker \
            --ifref=name \
            --global "WorkDir: ${WEBDIR}" \
            --global "Options[_]: growright, bits" \
            --global "LogFormat: rrdtool" \
            --subdirs=${NAME} \
            --no-down \
            --show-op-down \
            --snmp-options=:${PORT:-"161"}::::${VERSION:-"2"} \
            --output=${MRTGDIR}/conf.d/${NAME}.cfg "${COMMUNITY}@${HOST}"
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
            --global "LogFormat: rrdtool" \
            --snmp-options=:${PORT}::::${VERSION} \
            --output=${MRTGDIR}/conf.d/${NAME}.cfg "${COMMUNITY}@${HOST}"
fi

echo "Starting webserver"
service apache2 start
ln -s /var/www/html /var/www/mrtg
# cfgmaker ${SNMP_COMMUNITY}@${SNMP_HOST} > /tmp/mrtg.cfg
# cat /tmp/mrtg.cfg | sed 's/#\ Options\[_\]/Options\[_\]/' > /etc/mrtg.cfg

echo "#Global configuration" > /etc/mrtg.cfg
echo "WorkDir: /mrtg/html/html" >> /etc/mrtg.cfg
echo "Refresh: 600" >> /etc/mrtg.cfg
echo "WriteExpires: Yes" >> /etc/mrtg.cfg
echo "PathAdd: /usr/bin" >> /etc/mrtg.cfg
echo "" >> /etc/mrtg.cfg
echo "Title[^]: Traffic Analysis for" >> /etc/mrtg.cfg
echo "Options[_]: growright,bits" >> /etc/mrtg.cfg
# echo "Include: /etc/mrtg/conf.d/*.cfg" >> /etc/mrtg.cfg

# cp /etc/mrtg.tmp /etc/mrtg.cfg

echo "Starting mrtg"
/usr/bin/mrtg
sleep 2

# echo "Creating all.html file"
# /usr/bin/indexmaker --output /mrtg/html/html/all.html --columns=3 /etc/mrtg.cfg
# sleep 2

# echo "Starting mrtg"
# /usr/bin/mrtg

echo "Creating host.cfg files"
if [ -n "${HOSTS}" ]; then
    for asset in ${hosts}; do
        read -r COMMUNITY HOST VERSION PORT < <(echo ${asset} | sed -e 's/:/ /g')
        NAME=${HOST}
        echo "Indexing $NAME"
        echo "" >> /etc/mrtg.cfg
        cat /etc/mrtg/conf.d/$NAME.cfg >> /etc/mrtg.cfg
        NAME_LOWER=$(echo $NAME | tr '[:upper:]' '[:lower:]')
        /usr/bin/indexmaker --output /mrtg/html/html/${NAME_LOWER}.html --columns=3 --filter name=~${NAME_LOWER} --title="${NAME} Interface Statistics" /etc/mrtg.cfg
        sleep 2
    done
fi

# echo "Creating all.html file"
# /usr/bin/indexmaker --output /mrtg/html/html/all.html --columns=3 /etc/mrtg.cfg
# sleep 2

# indexmaker /etc/mrtg.cfg > /var/www/html/index.html

echo "Start polling cycle"

while (true); do /usr/bin/mrtg; sleep 300; done
