# service2https

This project provides a single-file shell script 
to easily deploy a services from a Docker image 
to the public on an Internet-connected machine/VM.

The service2https tool wraps the actual service
by an nginx web server/reverse proxy
that adds real https with valid and cost-free
[Let's Encrypt](https://letsencrypt.org/) https/TLS certificates.

Internally, these technologies are used:
* [Docker](https://www.docker.com/)
* [Docker Compose](https://docs.docker.com/compose/)
* [nginx](https://www.nginx.com/)
* [certbot](https://certbot.eff.org/) as [ACME client](https://letsencrypt.org/de/docs/client-options/)


Preconditions
-------------
What we need before we start:
* the service available as Docker image/OCI image
* an Internet-connected machine/VM with public IP address and open ports 80 and 443,
  plus shell access, usually with ssh/port 22 (no extra load balancer is needed)
* a domain name (e.g. demo.example.com) mapped to this IP address


Limitations
-----------
* it's intended for a single machine/VM per domain setup, i.e. for test and experimental use only
  * for multiserver setup use a solid load balancer with TLS-termination in front of your service nodes


Usage
-----
To run service2https:
* download [service2https-docker-compose.sh](./service2https-docker-compose.sh]
* set your configuration in environment variables, e.g. as follows:
  * use an `.env` file
    * download [service2https-docker-compose.env](./service2https-docker-compose.env]
    * modify the entries
    * load it, e.g. with `. ./service2https-docker-compose.env`
  * set the environment variables in a different way
* start the configuration
    ```
    .      service2https-docker-compose.env
    sudo ./service2https-docker-compose.sh up
    ```
  you can also add `-d` to run in daemon mode (see all options with `./service2https-docker-compose.sh up --help`)
* stop the configuration
    ```
    ./service2https-docker-compose.sh down
    ```


Further Information
-------------------
Links:
* [Using docker-compose With Private Repositories](https://www.baeldung.com/linux/docker-compose-private-repositories)



Feedback/Contact
----------------

chris at aisbreaker  org

