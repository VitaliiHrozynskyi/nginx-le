#!/bin/sh
echo "start nginx"
#sleep 6000
#set TZ
cp /usr/share/zoneinfo/${TZ} /etc/localtime
echo ${TZ} > /etc/timezone

##setup ssl keys
echo "ssl_key=${SSL_KEY:=le-key.pem}, ssl_cert=${SSL_CERT:=le-crt.pem}, ssl_chain_cert=${SSL_CHAIN_CERT:=le-chain-crt.pem}"
#
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/ssl

#collect services

SERVICES=$(find "/etc/nginx/services" -type f -name "*.conf")
echo $SERVICES;
# prepare domain for mounting
for mountFile in $SERVICES; do
  echo $domainName;
  domainName=$(sed -n "s/.*nginx-le-domain\s*\(.*\)\s*/\1/p" $mountFile);
  domainDir="/etc/nginx/ssl/$domainName"
  confFile=/etc/nginx/conf.d/"$domainName".conf
  mkdir -m 0700 -p "$domainDir";
  cp -fv $mountFile $confFile

  sed -i "s|SSL_KEY|${domainDir}/${SSL_KEY}|g" $confFile
  sed -i "s|SSL_CERT|${domainDir}/${SSL_CERT}|g" $confFile
  sed -i "s|SSL_CHAIN_CERT|${domainDir}/${SSL_CHAIN_CERT}|g" $confFile
  if [[ ! -f ${domainDir}/$SSL_KEY || ! -f ${domainDir}/$SSL_CERT || ! -f ${domainDir}/$SSL_CHAIN_CERT ]]; then
    echo "certificate for $domainName not found, lets create a self signed one to ensure NGINX can start"
    ./openssl.sh $domainName $domainDir $SSL_KEY $SSL_CERT $SSL_CHAIN_CERT
  fi
done

#generate dhparams.pem
if [ ! -f /etc/nginx/ssl/dhparams.pem ]; then
    echo "make dhparams"
    cd /etc/nginx/ssl
    openssl dhparam -out dhparams.pem 2048
    chmod 600 dhparams.pem
fi

(
  sleep 5 #give nginx time to start
  echo "start letsencrypt updater"
  while :
  do
    rm -f /etc/nginx/conf.d/default.conf 2>/dev/null #on the first run remove default config, conflicting on 80
    restart=false;
    delay=10d;
    for mountFile in $SERVICES; do
      domainName=$(sed -n "s/.*nginx-le-domain\s*\(.*\)\s*/\1/p" $mountFile);
      # skip LE domain if there is no le-domain var in conf file.
      if [[ $domainName != '' ]]; then
        domainDir="/etc/nginx/ssl/$domainName"
        confFile=/etc/nginx/conf.d/"$domainName".conf
        /le.sh $domainName $domainDir $SSL_KEY $SSL_CERT $SSL_CHAIN_CERT
        success=$(echo $?);
        if [ $success -eq 1 ]; then
          delay=15m
        elif [ $success -eq 2 ]; then
          restart=true;
        fi
      fi
    done

    if [ restart ]; then
      echo "reload nginx with ssl"
    nginx -s reload
    fi
    sleep $delay
  done
) &

nginx -g "daemon off;"
