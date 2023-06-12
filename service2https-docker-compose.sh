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
#####

# set specified default values if env variable is not set yet
export SERVICEIMAGE="${SERVICEIMAGE:=nginxdemos/hello:latest}"
export SERVICEIMAGE_PORT="${SERVICEIMAGE_PORT:=80}"

echo "-- service2https: Overall configuration:"
env | grep "SERVICEIMAGE" | sort

#####
# Service configuration -
# These environment variables will be passed to the service, with prefix 'SERVICE_' removed.
# E.g. SERVICE_PROPERTY_1 -> PROPERTY_1 , SERVICE_FOOBAR -> FOOBAR, ...
#####

# set specified default values if env variable is not set yet
export SERVICE_PROPERTY_1="Hello"
export SERVICE_PROPERTY_2="World"

echo "-- service2https: Service configuration:"
env | grep "SERVICE_" | sort



####################
# Common code -
# Should not be modified
####################

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
echo "-- service2https: Service configuration (yaml snipped):"
echo "${SERVICEENVIRONMENT}"


# generate docker-compose.yml,
# inspired by [pierreozoux](https://github.com/pierreozoux) in [Docker Compose: inline file](https://github.com/docker/compose/issues/3538)
cat > "${VARDIR}/docker-compose.yml" <<EOCOMPOSEYML
services:
  theservice:
    container_name: theservice
    image: ${SERVICEIMAGE}
    ports:
      - 8080:${SERVICEIMAGE_PORT}
    #env_file:
    #  - ./env_file
${SERVICEENVIRONMENT}

  nginx:
    container_name: nginx
    restart: unless-stopped
    image: nginx
    ports:
      - 80:80
      - 443:443
    #volumes:
    #  - ./nginx/nginx.conf:/etc/nginx/nginx.conf
        
    command: |
        bash -c 'bash -s <<EOSCRIPT
          cat > /etc/nginx/nginx.conf <<EONGINX
            events {
                worker_connections  1024;
            }

            http {
                server_tokens off;
                charset utf-8;

                server {
                    listen 80 default_server;

                    server_name _;

                    location / {
                        proxy_pass http://theservice:80/;
                    }
                }
            }
        EONGINX

        echo "HELLO FROM SCRIPT"
        ls -l /etc/nginx/nginx.conf

        nginx -g "daemon off;"
        EOSCRIPT'
EOCOMPOSEYML

# determine and execute docker compose command
cd "${VARDIR}"
echo "-- service2https: Check for command docker compose' and 'docker compose'"
if docker compose version; then
    # success: Execute now
    echo "-- service2https execute now: docker compose $@"
    docker compose "$@"
elif docker-compose version; then
    # success: Execute now
    echo "-- service2https execute now: docker-compose $@"
    docker-compose "$@"
else
    echo "-- service2https ERROR: Command 'docker compose' and 'docker compose' NOT FOUND"
    exit 1
fi

