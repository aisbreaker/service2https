#!/bin/bash

####################
#
# # set env variables, optionally take defaults from the ./service2https-docker-compose.sh
# export SERVICEIMAGE="mydocker/serviceimage"
# export SERVICE_MY_SERVICE_PROP_1="Hello"
#
# start the service (and create a local working dir "./service2https-var"
# ./service2https-docker-compose.sh
#
####################

#####
# Overall configuration
#
# Set default values if env variable is not set
#####

# Docker image of the service - DEFAULTS
export SERVICEIMAGE="${SERVICEIMAGE:=nginxdemos/hello:latest}"
export SERVICEIMAGE_PORT="${SERVICEIMAGE_PORT:=80}"

# Domain of the service (DNS/IP must point to this server/VM) - DEFAULTS
export SERVICEDOMAIN="${SERVICEDOMAIN:=example.com}"

# Let's Encrypt configuration:
# Adding a valid address is strongly recommended, to be able to receive important cert-related infos and warnings - DEFAULTS
export SERVICEEMAIL="${SERVICEEMAIL:=letsencrypt@example.com}"
# Let's Encrypt configuration:
# Staging: Set to 1 if you're testing your setup to avoid hitting request limits - DEFAULTS
export LETS_ENCRYPT_STAGING="${LETS_ENCRYPT_STAGING:=0}"


# Summary
echo "### service2https: Overall configuration:"
env | grep "SERVICEIMAGE"  | sort
env | grep "SERVICEDOMAIN" | sort
env | grep "SERVICEEMAIL"  | sort


#####
# Service configuration -
# These environment variables will be passed to the service, with prefix 'SERVICE_' removed.
# E.g. SERVICE_PROPERTY_1 -> PROPERTY_1 , SERVICE_FOOBAR -> FOOBAR, ...
#
# Set default values if env variable is not set
#####

# random example vars - DEFAULTS
export SERVICE_PROPERTY_1="Hello"
export SERVICE_PROPERTY_2="World"


# Summary
echo "### service2https: Service configuration:"
env | grep "SERVICE_" | sort



####################
# Common code -
# Should not be modified
####################

echo "### service2https: Started ... $(date -u +"%Y-%m-%dT%H:%M:%SZ") ..."


export VARDIR="${PWD}/service2https-var"
mkdir -p "${VARDIR}"

# extract and copy service-specific vars,
# with prefix 'SERVICE_' removed.
# E.g. SERVICE_PROPERTY_1 -> PROPERTY_1 , SERVICE_FOOBAR -> FOOBAR, ...
export SERVICE_AT_LEAST="One SERVICE_* variable must be set for this algorithm to work"
export SERVICEENVIRONMENT="    environment:"
for var in "${!SERVICE_@}"; do
    SERVICEENVIRONMENT=`printf '%s\n      - %s="%s"' "${SERVICEENVIRONMENT}" "${var:8}" "${!var}"`
done
echo "### service2https: Service configuration (yaml snipped):"
echo "${SERVICEENVIRONMENT}"


# generate docker-compose.yml,
# inspired by [pierreozoux](https://github.com/pierreozoux) in [Docker Compose: inline file](https://github.com/docker/compose/issues/3538)
cat > "${VARDIR}/docker-compose.yml" <<-EoCOMPOSEYML
---
version: '3'
services:
  theservice:
    container_name: theservice
    image: ${SERVICEIMAGE}
    ports:
      - 8080:${SERVICEIMAGE_PORT}
    #env_file:
    #  - ./env_file
${SERVICEENVIRONMENT}

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    #command: certonly --webroot -w /var/www/certbot --force-renewal --email ${SERVICEEMAIL} -d ${SERVICEDOMAIN} --agree-tos
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

  nginx:
    container_name: nginx
    restart: unless-stopped
    image: nginx
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    #  - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    command: |
        bash -c 'bash -s <<EoSCRIPT
          echo "nginx command started ... $(date -u +"%Y-%m-%dT%H:%M:%SZ") ..."
          cat > /etc/nginx/nginx.conf <<EoNGINX
            events {
                worker_connections  1024;
            }

            http {
                server_tokens off;
                charset utf-8;

                server {
                    listen 80 default_server;

                    server_name _;

                    location ~ /.well-known/acme-challenge/ {
                        root /var/www/certbot;
                    }

                    #return 301 https://$host$request_uri;

                    location / {
                        proxy_pass http://theservice:${SERVICEIMAGE_PORT}/;
                    }
                    #location ~ /.well-known/acme-challenge/ {
                    #    root /var/www/certbot;
                    #}
                }

                server {
                    listen 443 ssl http2;

                    #access_log /var/log/nginx/access.log combined_ssl;

                    # use the certificates
                    ssl_certificate     /etc/letsencrypt/live/${SERVICEDOMAIN}/fullchain.pem;
                    ssl_certificate_key /etc/letsencrypt/live/${SERVICEDOMAIN}/privkey.pem;
                    include /etc/letsencrypt/options-ssl-nginx.conf;
                    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

                    server_name ${SERVICEDOMAIN};
                    root /var/www/html;
                    index index.php index.html index.htm;


                    location / {
                        proxy_pass http://theservice:${SERVICEIMAGE_PORT}/;
                    }

                    location ~ /.well-known/acme-challenge/ {
                        root /var/www/certbot;
                    }
                }

            }
        EoNGINX

          ls -l /etc/nginx/nginx.conf
          echo "-- cat /etc/nginx/nginx.conf:"
          cat /etc/nginx/nginx.conf
          echo "--"

          nginx -g "daemon off;"
          #/bin/sh -c 'while :; do sleep 6h & wait \$\${!}; nginx -s reload; done & nginx -g "daemon off"'
          #/bin/bash -c "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; sleep 10; done & nginx -g \"daemon off;\"'"

          echo "nginx started ..."
          ps aux | grep nginx

        EoSCRIPT'
EoCOMPOSEYML

# determine and docker compose command: 'docker compose' oder 'docker-compose'
export DOCKERCOMPOSE_CMD1=""
export DOCKERCOMPOSE_CMD2=""
cd "${VARDIR}"
echo "### service2https: Check for command docker compose' and 'docker compose'"
if docker compose version; then
    # success:
    echo "### service2https found: docker compose $@"
    export DOCKERCOMPOSE_CMD1="docker"
    export DOCKERCOMPOSE_CMD2="compose"
elif docker-compose version; then
    # success: Execute now
    echo "### service2https found: docker-compose $@"
    export DOCKERCOMPOSE_CMD1="docker-compose"
    export DOCKERCOMPOSE_CMD2=""
else
    echo "### service2https ERROR: Command 'docker compose' and 'docker compose' NOT FOUND"
    exit 1
fi


# Solve "The Chicken or the Egg?" problem,
# inspired by
#   https://pentacent.medium.com/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71
#   https://raw.githubusercontent.com/wmnnd/nginx-certbot/master/init-letsencrypt.sh

certbot_dir="${VARDIR}/certbot"

if [ -d "${certbot_dir}" ]; then
    #
    # found and use inital https/TLS certificate(s) or parts of it
    #

    #read -p "### service2https: Existing data found for $DOMAINS. Continue and replace existing certificate? (y/N) " decision
    #if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    #  exit
    #fi
    echo "### service2https: Existing data found for $DOMAINS."
    echo "                   If you don't want to use them, press: CTRL + C now ... and the delete dir '${VARDIR}' for a clean start."
    echo "                   Continue automatically in 10 seconds ... "
    sleep 10

else

    #
    # create initial https/TLS certificates with Let's Encrypt
    #
    DOMAINS=(${SERVICEDOMAIN})    # DOMAINS=(example.org www.example.org)
    echo "DOMAINS: '${DOMAINS}'"
    rsa_key_size=4096

    # implement security best-practices
    if [ ! -e "${certbot_dir}/conf/options-ssl-nginx.conf" ] || [ ! -e "${certbot_dir}/conf/ssl-dhparams.pem" ]; then
      echo "### service2https: Downloading recommended TLS parameters ..."
      mkdir -p "${certbot_dir}/conf"
      curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "${certbot_dir}/conf/options-ssl-nginx.conf"
      curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "${certbot_dir}/conf/ssl-dhparams.pem"
      echo
    fi

    echo "### service2https: Creating dummy certificate for $DOMAINS ..."
    path="/etc/letsencrypt/live/$DOMAINS"
    mkdir -p "${certbot_dir}/conf/live/$DOMAINS"
    ${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} run --rm --entrypoint "\
      openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
        -keyout '$path/privkey.pem' \
        -out '$path/fullchain.pem' \
        -subj '/CN=localhost'" certbot
    echo

    echo "### service2https: Starting nginx with dummy certificate for $DOMAINS ..."
    ${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} up --force-recreate -d theservice nginx
    echo

    echo "### service2https: Deleting dummy certificate for $DOMAINS ..."
    ${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} run --rm --entrypoint "\
      rm -Rf /etc/letsencrypt/live/$DOMAINS && \
      rm -Rf /etc/letsencrypt/archive/$DOMAINS && \
      rm -Rf /etc/letsencrypt/renewal/$DOMAINS.conf" certbot
    echo


    echo "### service2https: Requesting Let's Encrypt certificate for $DOMAINS ..."
    # Join $DOMAINS to -d args
    domain_args=""
    for domain in "${DOMAINS[@]}"; do
      domain_args="$domain_args -d $domain"
    done

    # Select appropriate email arg
    case "${SERVICEEMAIL}" in
      "") email_arg="--register-unsafely-without-email" ;;
      *) email_arg="--email ${SERVICEEMAIL} --no-eff-email" ;;
    esac

    # Enable staging mode if needed
    if [ ${LETS_ENCRYPT_STAGING} != "0" ]; then staging_arg="--staging"; fi

    # requesting inital Let's Encrypt certificate
    ${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} run --rm --entrypoint "\
      certbot certonly --webroot -w /var/www/certbot \
        $staging_arg \
        $email_arg \
        $domain_args \
        --rsa-key-size $rsa_key_size \
        --agree-tos \
        --force-renewal" certbot
    echo

    echo "### service2https: Restarting nginx - now with real certificate for $DOMAINS ..."
    ${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} exec nginx nginx -s reload

fi

#
# action
#
echo "### service2https: execute now ($(date -u +"%Y-%m-%dT%H:%M:%SZ")): ${DOCKERCOMPOSE_CMD} ${DOCKERCOMPOSE_ARG0} $@"
${DOCKERCOMPOSE_CMD1} ${DOCKERCOMPOSE_CMD2} "$@"

