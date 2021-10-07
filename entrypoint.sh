#!/bin/bash

service apache2 start
ln -s /var/www/html /var/www/mrtg
cfgmaker ${SNMP_COMMUNITY}@${SNMP_HOST} > /tmp/mrtg.cfg
cat /tmp/mrtg.cfg | sed 's/#\ Options\[_\]/Options\[_\]/' > /etc/mrtg.cfg
/usr/bin/mrtg
indexmaker /etc/mrtg.cfg > /var/www/html/index.html

while (true); do /usr/bin/mrtg; sleep 300; done
