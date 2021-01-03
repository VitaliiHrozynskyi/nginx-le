#!/bin/sh

# scripts is trying to renew certificate only if close (30 days) to expiration
# returns 0 only if certbot called.

SERVER=$1;
OUT_DIR=$2;
SSL_KEY=$3
SSL_CERT=$4
SSL_CHAIN_CERT=$5

# 30 days
renew_before=2592000

if [ "$LETSENCRYPT" != "true" ]; then
    echo "letsencrypt disabled"
    return 0
fi

# redirection to /dev/null to remove "Certificate will not expire" output

echo "trying to update letsencrypt for $SERVER in $OUT_DIR..."
if [ -f ${OUT_DIR}/${SSL_CERT} ] && openssl x509 -checkend ${renew_before} -noout -in ${OUT_DIR}/${SSL_CERT} > /dev/null ; then
    # egrep to remove leading whitespaces
    CERT_FQDNS=$(openssl x509 -in ${OUT_DIR}/${SSL_CERT} -text -noout | egrep -o 'DNS.*')
    echo "Certificate FQDNS = $CERT_FQDNS"

    # run and catch exit code separately because couldn't embed $@ into `if` line properly
    set -- $(echo ${SERVER} | tr ',' '\n'); for element in "$@"; do echo ${CERT_FQDNS} | grep -q $element ; done
    CHECK_RESULT=$?
    if [ ${CHECK_RESULT} -eq 0 ] ; then
        echo "letsencrypt certificate ${SSL_CERT} still valid"
        return 0
    else
        echo "letsencrypt certificate ${nT} is present, but doesn't contain expected domains"
        echo "expected: ${SERVER}"
        echo "found:    ${CERT_FQDNS}"
    fi
fi

echo "letsencrypt certificate will expire soon or missing, renewing... for $SERVER"
echo "running \"-t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${SERVER}\"";

certbot certonly -t -n --agree-tos --renew-by-default --email "${LE_EMAIL}" --webroot -w /usr/share/nginx/html -d ${SERVER}
le_result=$?
if [ ${le_result} -ne 0 ]; then
    echo "failed to run certbot"
    return 1
fi

FIRST_FQDN=$(echo "$SERVER" | cut -d"," -f1)
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/privkey.pem ${OUT_DIR}/${SSL_KEY}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/fullchain.pem ${OUT_DIR}/${SSL_CERT}
cp -fv /etc/letsencrypt/live/${FIRST_FQDN}/chain.pem ${OUT_DIR}/${SSL_CHAIN_CERT}
return 2