#!/bin/bash

MRTGDIR=${MRTGDIR:-"/etc/mrtg"}
WEBDIR=${WEBDIR:-"/mrtg/html"}
MRTGCFG=${MRTGDIR}/mrtg.cfg

[[ ! -d "${MRTGDIR}" ]] && mkdir -p ${MRTGDIR}
[[ ! -d "${WEBDIR}" ]] && mkdir -p ${WEBDIR}

if [ -n "${HOSTS}" ]; then
    hosts=$(echo ${HOSTS} | tr '[,;]' ' ')
    for asset in ${hosts}; do
        read -r COMMUNITY HOST VERSION PORT < <(echo ${asset} | sed -e 's/:/ /g')

        if [[ "${VERSION}" -eq "2" || -z "${VERSION}" ]]; then _snmp_ver="2c"; else _snmp_ver=${VERSION}; fi
        NAME=$(snmpwalk -Oqv -v${_snmp_ver} -c ${COMMUNITY} ${HOST}:${PORT:-"161"} .1.3.6.1.2.1.1.5)
        if [ -z "${NAME}" ]; then
            NAME="${HOST}"
        fi
        [[ ! -f "${MRTGDIR}/conf.d/${NAME}.cfg" ]] && /usr/bin/cfgmaker \
            --ifref=name \
            --global "WorkDir: ${WEBDIR}" \
            --global "Options[_]: growright, bits" \
            --global "EnableIPv6: ${ENABLE_V6}" \
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

service apache2 start
ln -s /var/www/html /var/www/mrtg
# cfgmaker ${SNMP_COMMUNITY}@${SNMP_HOST} > /tmp/mrtg.cfg
# cat /tmp/mrtg.cfg | sed 's/#\ Options\[_\]/Options\[_\]/' > /etc/mrtg.cfg
/usr/bin/mrtg

/usr/bin/indexmaker --output /mrtg/html/all.html --columns=4 /etc/mrtg/mrtg.cfg

if [ -n "${HOSTS}" ]; then
    hosts=$(echo ${HOSTS} | tr '[,;]' ' ')
    for asset in ${hosts}; do
        echo "Indexing $asset"
        /usr/bin/indexmaker --output /mrtg/html/${asset}.html --columns=4 --filter name=~${asset} --title="${asset} Interface Statistics" /etc/mrtg/mrtg.cfg
    done
fi

# indexmaker /etc/mrtg.cfg > /var/www/html/index.html

while (true); do /usr/bin/mrtg; sleep 300; done
