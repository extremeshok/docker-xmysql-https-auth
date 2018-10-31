# docker-xmysql-https-auth
xmysql with https and auth via apikey and/or htpasswd and/or ip

## Authentication methods, set in docker-compose.yml, see docker-compose-sample.yml
### api key in header (X-API-KEY)
API_KEY=asecurekey

### http auth_basic
* htpasswd encrypted password *
API_HTTP_AUTH=user:encryptedpassword
* plaintext password *
API_HTTP_AUTH=user:{plain}password

### IP allow
* ip with netmask *
API_ALLOW_IP=11.22.33.0/24
* ip without netmask *
API_ALLOW_IP=11.22.33.44

## Notes:
xmysql will wait for MySQL to warm-up, checks every 2 seconds
httpS only (port 443), http (port 80) will redirect all requests to httpS

API_KEY, API_HTTP_AUTH and API_ALLOW_IP are all optional, you may enable 1 or more.
If API_KEY and/or API_HTTP_AUTH and/or API_ALLOW_IP are enabled, all will be required for a successful auth.
