#!/bin/bash

TARGETCOUNT=0

create_dirs() {
    mkdir /run/lock
    MRTGDIR=${MRTGDIR:-"/etc/mrtg"}
    WEBDIR=${WEBDIR:-"/var/www/html"}
    MRTGCFG=/etc/mrtg.cfg

    [[ ! -d "${MRTGDIR}" ]] && mkdir -p ${MRTGDIR}
    [[ ! -d "${WEBDIR}" ]] && mkdir -p ${WEBDIR}
}

create_target_configs() {
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
                --ifref=name,eth,ip \
                --global "WorkDir: $WEBDIR" \
                --global "Options[_]: growright, bits" \
                --subdirs=${NAME_UPPER} \
                --no-down \
                --show-op-down \
                --snmp-options=:${PORT:-"161"}::::${VERSION:-"2"} \
                --output=${MRTGDIR}/conf.d/${NAME_UPPER}.cfg "${COMMUNITY}@${HOST}"
            echo "" >> ${MRTGCFG}
            cat ${MRTGDIR}/conf.d/$NAME_UPPER.cfg >> ${MRTGCFG}
            let TARGETCOUNT++
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
            --ifref=name,eth,ip \
            --global "Options[_]: growright, bits" \
            --global "EnableIPv6: ${ENABLE_V6}" \
            --snmp-options=:${PORT}::::${VERSION} \
            --output=${MRTGDIR}/conf.d/${NAME}.cfg "${COMMUNITY}@${HOST}"
    fi
}

refresh_target_configs() {
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
            # [[ ! -f "${MRTGDIR}/conf.d/${NAME_UPPER}.cfg" ]] && /usr/bin/cfgmaker \
            /usr/bin/cfgmaker \
                --ifref=name,eth,ip \
                --global "WorkDir: $WEBDIR" \
                --global "Options[_]: growright, bits" \
                --subdirs=${NAME_UPPER} \
                --no-down \
                --show-op-down \
                --snmp-options=:${PORT:-"161"}::::${VERSION:-"2"} \
                --output=${MRTGDIR}/conf.d/${NAME_UPPER}.cfg "${COMMUNITY}@${HOST}"
            let TARGETCOUNT++
            echo "" >> ${MRTGCFG}
            cat ${MRTGDIR}/conf.d/$NAME_UPPER.cfg >> ${MRTGCFG}
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
            --ifref=name,eth,ip \
            --global "Options[_]: growright, bits" \
            --global "EnableIPv6: ${ENABLE_V6}" \
            --snmp-options=:${PORT}::::${VERSION} \
            --output=${MRTGDIR}/conf.d/${NAME}.cfg "${COMMUNITY}@${HOST}"
    fi
}

create_config_file() {
    echo "#Global configuration" > ${MRTGCFG}
    echo "WorkDir: $WEBDIR" >> ${MRTGCFG}
    echo "Refresh: 600" >> ${MRTGCFG}
    echo "WriteExpires: Yes" >> ${MRTGCFG}
    echo "PathAdd: /usr/bin" >> ${MRTGCFG}
    echo "" >> ${MRTGCFG}
    echo "Title[^]: Traffic Analysis for" >> ${MRTGCFG}
    echo "Options[_]: growright,bits" >> ${MRTGCFG}
    # echo "Include: ${MRTGDIR}/conf.d/*.cfg" >> ${MRTGCFG}
}

create_index_files() {
    if [ -n "${HOSTS}" ]; then
        for asset in ${hosts}; do
            read -r COMMUNITY HOST VERSION PORT < <(echo ${asset} | sed -e 's/:/ /g')
            NAME=${HOST}
            NAME_LOWER=$(echo $NAME | tr '[:upper:]' '[:lower:]')
            NAME_UPPER=$(echo $NAME | tr '[:lower:]' '[:upper:]')
            echo "Indexing $NAME_UPPER"
            echo "" >> ${MRTGCFG}
            # cat ${MRTGDIR}/conf.d/$NAME_UPPER.cfg >> ${MRTGCFG}
            [[ ! -f "${WEBDIR}/${NAME_UPPER}.html" ]] && /usr/bin/indexmaker \
                --output ${WEBDIR}/${NAME_UPPER}.html \
                --columns=3 \
                --filter name=~${NAME_LOWER} \
                --title="${NAME} Interface Statistics" ${MRTGCFG}
            # /usr/bin/indexmaker --output ${WEBDIR}/${NAME_UPPER}.html --columns=3 --filter name=~${NAME_LOWER} --title="${NAME} Interface Statistics" ${MRTGCFG}
            sleep 2
        done
    fi
}

echo "Setting ServerName"
echo "ServerName ${HOSTNAME}.${DOMAINNAME}" >> /etc/apache2/apache2.conf

echo "Creating Directories"
create_dirs

echo "Creating Target Configs"
create_target_configs

echo "Starting webserver"
service apache2 start
ln -s /var/www/html /var/www/mrtg

echo "Creating mrtg.cfg"
create_config_file

echo "Starting mrtg"
/usr/bin/mrtg
sleep 2

echo "Creating index files"
create_index_files

echo "Creating all.html file"
/usr/bin/indexmaker --output ${WEBDIR}/all.html --columns=3 ${MRTGCFG}
sleep 2

indexmaker /etc/mrtg.cfg > /var/www/html/index.html

echo "Creating cronjob to Refresh Configs Every 24hrs"
crontab - l | { cat; echo "55 1 * * * rm /etc/mrtg.cfg"; } | crontab -
crontab - l | { cat; echo "0 2 * * * /entrypoint.sh refresh_target_configs"; } | crontab -

echo "Start polling cycle on $TARGETCOUNT total devices"

while (true); do 
    /usr/bin/mrtg 
    sleep 600
    echo "Polling Targets"
    # create_target_configs 
done

"$@"
