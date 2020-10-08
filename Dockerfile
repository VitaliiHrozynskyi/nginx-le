FROM nginx:1.17.8-alpine

RUN \
 apk add  --update certbot tzdata openssl ca-certificates && \
 rm -rf /var/cache/apk/*

ADD conf/nginx.conf /etc/nginx/nginx.conf

ADD script/entrypoint.sh /entrypoint.sh
ADD script/le.sh /le.sh
ADD script/openssl.sh /openssl.sh
#ADD script/openssl.cnf /etc/ssl/openssl.cnf

RUN \
 rm /etc/nginx/conf.d/default.conf && \
 chmod +x /entrypoint.sh && \
 chmod +x /le.sh && \
 chmod +x /openssl.sh

VOLUME [ "/etc/nginx/ssl" ]

CMD ["/entrypoint.sh"]
