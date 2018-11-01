#!/usr/bin/env bash


echo "#### Nginx SSL requirements ####"

if [ -d "/certs" ] && [ -w "/certs/" ] ; then
  if [ ! -f "/certs/dhparam.pem" ] ; then
    echo "==== Generating 4096 dhparam ===="
    openssl dhparam -out /certs/dhparam.pem 4096
    chmod 644 /certs/dhparam.pem
  fi
  if [ -r "/certs/${API_HOSTNAME}/fullchain.pem" ] && [ -r "/certs/${API_HOSTNAME}/privkey.pem" ] && [ -r "/certs/${API_HOSTNAME}/chain.pem" ] ; then
    echo "==== Detected ${API_HOSTNAME}: fullchain,privkey,chain ===="
  elif [ -r "/certs/cert.pem" ] && [ -r "/certs/privkey.pem" ] ; then
    echo "==== Detected: /certs: cert,privkey ===="
  else
    echo "==== Generating Self-signed certificate and key ===="
    openssl genrsa -des3 -passout pass:x -out /certs/server.pass.key 2048
    openssl rsa -passin pass:x -in /certs/server.pass.key -out /certs/privkey.pem
    rm -f /certs/server.pass.key
    openssl req -new -key /certs/privkey.pem -out /certs/server.csr -subj "/C=UK/ST=Warwickshire/L=Leamington/O=OrgName/OU=IT Department/CN=example.com"
    openssl x509 -req -days 3650 -in /certs/server.csr -signkey /certs/privkey.pem -out /certs/cert.pem
    rm -f /certs/server.csr
    chmod 644 /certs/cert.pem
    chmod 644 /certs/privkey.pem

    if [ ! -r "/certs/cert.pem" ] || [ ! -r "/certs/privkey.pem" ] ; then
      echo "Failure: Generating certificate"
      sleep 60
      exit 1
    fi
  fi
fi

while ! [ -r "/certs/${API_HOSTNAME}/fullchain.pem" ] && [ -r "/certs/${API_HOSTNAME}/privkey.pem" ] ; do
  echo "Waiting for certs to be provisioned..."
  sleep 2
done

# Wait for th

echo "#### Generating Nginx API config ####"

cat <<EOF > "/etc/nginx/conf.d/api.conf"
########################## *. httpS (443) ##########################
server {
  listen 443 ssl http2 backlog=256;
  server_name ${API_HOSTNAME:-_};

  root        /var/www;
  index       index.html index.htm;

  include /etc/nginx/includes/ssl.conf;
EOF

if [ -r "/certs/${API_HOSTNAME}/fullchain.pem" ] && [ -r "/certs/${API_HOSTNAME}/privkey.pem" ] && [ -r "/certs/${API_HOSTNAME}/chain.pem" ] ; then
  cat <<EOF >> "/etc/nginx/conf.d/api.conf"
  ssl_certificate /certs/${API_HOSTNAME}/fullchain.pem;
  ssl_certificate_key /certs/${API_HOSTNAME}/privkey.pem;
  ssl_trusted_certificate /certs/${API_HOSTNAME}/chain.pem;
EOF
else
  cat <<EOF >> "/etc/nginx/conf.d/api.conf"
  ssl_certificate /certs/cert.pem;
  ssl_certificate_key /certs/privkey.pem;
EOF
fi

cat <<EOF >> "/etc/nginx/conf.d/api.conf"
  include /etc/nginx/includes/denies.conf;

  location / {
    autoindex off;
EOF

if [ ! -z "$API_ALLOW_IP" ] && [ ! -z "$API_HTTP_AUTH" ] ; then
  #require both allowed IP and HTTP_AUTH
  echo "satisfy all;" >> "/etc/nginx/conf.d/api.conf"
fi

if [ ! -z "$API_ALLOW_IP" ] ; then
  #prepare the varibles
  API_ALLOW_IP="$(echo ",${API_ALLOW_IP}," | tr -s "[:blank:]" "," | tr -s "," )"
  # remove beginning ,
  API_ALLOW_IP=${API_ALLOW_IP/#,}
  # remove ending ,
  API_ALLOW_IP=${API_ALLOW_IP/%,}
  #convert to spaces
  API_ALLOW_IP=${API_ALLOW_IP//,/ }
  for allowed_ip in $API_ALLOW_IP ; do
    #make sure there are no empty ip's
    if [ "$allowed_ip" != "" ]; then
      echo "allow ${allowed_ip};" >> "/etc/nginx/conf.d/api.conf"
    fi
  done
  echo "deny all;" >> "/etc/nginx/conf.d/api.conf"
fi

if [ ! -z "$API_HTTP_AUTH" ] ; then
  echo 'auth_basic "Authorized only";' >> "/etc/nginx/conf.d/api.conf"
  echo "auth_basic_user_file /etc/nginx/includes/htpasswd.conf;" >> "/etc/nginx/conf.d/api.conf"
  echo -e "${API_HTTP_AUTH}\\n" > "/etc/nginx/includes/htpasswd.conf"
fi

if [ ! -z "$API_KEY" ] ; then
  cat <<EOF >> "/etc/nginx/conf.d/api.conf"
  # throw 403 with compatible JSON error response if no X-API-KEY header match was made
  if (\$http_x_api_key != '${API_KEY}') {
    add_header 'Content-Type' 'application/json;charset=UTF-8' always;
    return 403 '{"success": false, "data":{"message":"Invalid API Key", "url": "\$request_uri", "code":403}}';
  }
EOF
fi

cat <<EOF >> "/etc/nginx/conf.d/api.conf"
    # SEO URL FIX
    rewrite ^/(.*) /\$1 break;
    # Proxy to xmysql
    proxy_redirect off;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass http://127.0.0.1:3000;
  }
}
EOF

if ! nginx -t ; then
  cat /etc/nginx/conf.d/api.conf
fi
