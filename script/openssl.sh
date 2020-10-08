#!/bin/sh

set -e

CA_DIR=./demoCA

if [ -z "$1" ]; then
  return 1
fi
SERVER=$1;
OUT_DIR=$2;
SUBJECT=/C=CA/ST=Canada/L=Canada/O=IT/CN=$1
SSL_KEY=$3
SSL_CERT=$4
SSL_CHAIN_CERT=$5

#create tmp dir
for d in "private" "certs" "crl" "newcerts"; do
  mkdir -m 0700 -p "${CA_DIR}"/"$d";
done


# Serial and registry
echo 1000 > "${CA_DIR}"/serial
touch "${CA_DIR}"/index.txt

openssl req \
        -new \
        -newkey rsa:4096 -days 365 \
        -nodes -x509 \
        -subj "${SUBJECT}" \
        -keyout "${CA_DIR}"/private/cakey.pem  \
        -out "${CA_DIR}"/cacert.pem

chmod 0400 "${CA_DIR}"/private/cakey.pem

openssl genrsa -out server.key 4096
openssl req -new -newkey rsa:4096 -key server.key -out server.csr \
        -subj "${SUBJECT}"

# Sign the certificate!
openssl ca -in server.csr -out server.pem -batch

cp server.key $OUT_DIR/$SSL_KEY
sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' server.pem > \
    $OUT_DIR/$SSL_CERT

cp "${CA_DIR}"/cacert.pem $OUT_DIR/$SSL_CHAIN_CERT

rm -R -f $CA_DIR ./server.csr ./server.key ./server.pem
