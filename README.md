# mrtg

MRTG (Multi Router Traffic Grapher) in a ~~box~~ container!

## ENV

To usage we need declare two environment variables:

- **SNMP_COMMUNITY**
- **SNMP_HOST**

## Example

```bash
docker run --rm -ti -e SNMP_COMMUNITY=public -e SNMP_HOST=192.168.0.1 -p 8080:80  lpsouza/mrtg
```

Run MRTG to monitoring a SNMP device (`192.168.0.1`) using `public` community.
