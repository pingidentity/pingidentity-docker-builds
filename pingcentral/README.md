# Ping Identity PingCentral Docker Image

<a name="contents"></a>
## Contents ##
- [Documentation](#documentation)
- [Devops License](#devops-license)
- [Getting Started](#getting-started)
- [Running PingCentral with Docker](#running-with-docker)
  - [Docker with External Database](#docker-external-db)
  - [Docker with H2](#docker-h2)
- [Running PingCentral with Docker-Compose](#running-with-docker-compose)
  - [Docker-Compose with MySQL](#docker-compose-mysql)
  - [Docker-Compose with H2](#docker-compose-h2)
- [Commercial Support](#commercial-support)
- [Copyright](#copyright)

<a name="documentation"></a>
## Documentation

* [PingCentral Docker Image](https://pingidentity-devops.gitbook.io/devops/docker-images/pingcentral) - Information on this image
    * Note: this pag not yet available

* [DevOps Program Documentation](https://pingidentity-devops.gitbook.io/devops) - Getting started with Ping Identity DevOps Program

* [DevOps Github Repos](https://github.com/topics/ping-devops) - Docker Builds, Getting Started and Server Profiles

<a name="devops-license"></a>
## Devops License

Before running this image, you must obtain an evaluation [license](https://pingidentity-devops.gitbook.io/devops/prod-license).

<a name="getting-started"></a>
## Getting Started
Before getting started, you will need to obtain a valid PingCentral license. 
You will then need to override the existing license with your valid license in `pingcentral/conf`.

<a name="running-with-docker"></a>
## Running PingCentral with Docker

<a name="docker-external-db"></a>
### Running PingCentral Docker With an External Database (MySQL / PostgreSQL / RDS / etc)
On first startup with a database, PingCentral creates a hostkey which is used in concert with the database.  
If you are not planning on starting PingCentral up with a completely fresh external database every run, this hostkey needs to be preserved.

The first step in this process is to first obtain the hostkey:
 - Edit `pingcentral/conf/mysql/application.properties` to contain the correct information for your MySQL database
 - Startup PingCentral in Docker: `docker run --name pingcentral -d -p 9022:9022 ping/pingcentral`
 - Once PingCentral is running, Copy the hostkey that was automatically created out of the Docker container and onto your local filesystem: 
    `docker cp pingcentral:/opt/pingcentral/conf/pingcentral.jwk .`
 - Place this pingcentral.jwk file somewhere safe. For this example, we will place it in `pingcentral/conf/mysql/`

Now all future runs of pingcentral in docker will properly start and connect to your database with the following command:
`docker run --name pingcentral --volume pingcentral/conf/mysql/pingcentral.jwk:/opt/pingcentral/conf/pingcentral.jwk -d -p 9022:9022 ping/pingcentral`

- Note: If you wish to use a different database, or destroy your database, you will need to redo this process.

<a name="docker-h2"></a>
### Running PingCentral Docker with H2
The H2 database resides in the file system.  In order to preserve the database between docker runs and avoid its destruction, 
the H2 database must be preserved in a volume.  You can do this by specifying a volume when running docker:

`docker run --name pingcentral --volume pingcentral/conf/h2/pingcentral.jwk:/opt/pingcentral/conf/pingcentral.jwk --volume pingcentral/conf/h2/pingcentral.mv.db:/opt/pingcentral/h2-data/pingcentral.mv.db -d -p 9022:9022 ping/pingcentral`

A blank H2 database and its associated hostkey is included in `pingcentral/conf/h2` for your use.

<a name="running-with-docker-compose"></a>
## Running PingCentral with Docker-Compose
<a name="docker-compose-mysql"></a>
### Running PingCentral Docker-Compose with MySQL
Starting up PingCentral with docker-compose with a blank MySQL database is as simple as running the command:

`docker-compose -f docker-compose-mysql.yml up -d`

To preserve the database between runs, simply use the command: `docker-compose -f docker-compose-mysql.yml stop` instead of `down`. 

If you wish to copy the database files out of the container, you can use the command: `docker cp mysql:/var/lib/mysql /path/to/save`

<a name="docker-compose-h2"></a>
### Running PingCentral Docker-Compose with H2
The docker-compose file for PingCentral and an H2 database is located at `pingcentral/docker-compose-h2.yml`

A blank H2 database and its associated hostkey is included in `pingcentral/conf/h2` for your use. 
By default, the h2 docker compose file will preserve the database between runs in this pingcentral/conf/h2 location.
If you wish to start PingCentral up with a blank database on each run, simply edit the `docker-compose-h2.yml` file and remove the following lines:
```$xslt
volumes:
      - ./conf/h2/pingcentral.jwk:/opt/pingcentral/conf/pingcentral.jwk
      - ./conf/h2/pingcentral.mv.db:/opt/pingcentral/h2-data/pingcentral.mv.db
```

Starting up PingCentral with docker-compose with an embedded H2 is as simple as running the command:

`docker-compose -f docker-compose-h2.yml up -d`

<a name="commercial-support"></a>
## Commercial Support

THE SOFTWARE PROVIDED HEREUNDER IS PROVIDED ON AN "AS IS" BASIS, WITHOUT
ANY WARRANTIES OR REPRESENTATIONS EXPRESS, IMPLIED OR STATUTORY.

Please contact devops_program@pingidentity.com for details

<a name="copyright"></a>
## Copyright

Copyright © 2019 Ping Identity. All rights reserved.