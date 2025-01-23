# Deployment of docker containers

It works for macos

+ Deploy PostgreSQL and create the demo database with Docker
+ Deploy Oracle with Docker
+ Deploy Greenplum with Docker (single-node)

## Deploy PostgreSQL with Docker

Run the postgresql.sh script

```
sh postgresql.sh
```

## Deploy Oracle with Docker

Run the oracle.sh script

```
sh oracle.sh
```

## Deploy Greenplum with Docker (single-node)

 1. Dowload Greenplum 6.25.3 from https://repo.datasapience.ru/repository/gp_raw_public/components/greenplum-db/6.25.3/greenplum-db-6.25.3-ubuntu22.04-x86_64.tar.gz 
 2. Move the downloaded filefile to ./greenplum/images/tmp 
 3. Run the greenplumdb_singlenode.sh

```
cd greenplum
sh greenplumdb_singlenode.sh
```

After the script is executed, follow these steps:

 1. Execute the command 'bash' in a running container as the gpadmin user.
    ```
    docker exec -it -u gpadmin greenplumdb_singlenode bash
    ```
 2. Distribute SHH public keys to all the hosts listed in the host_singlenode file.
    ```
    gpssh-exkeys -f /usr/local/greenplum-db/host_singlenode
    ```
 3. Initialize Greenplum cluster with single-node configuration.
    ```
    gpinitsystem -c /usr/local/greenplum-db/gpinitsystem_singlenode -h /usr/local/greenplum-db/host_singlenode
    ```
 4. Create user and grant privileges, also create extension pgcrypto (optional).
    ```
    psql -U gpadmin -d postgres
    create user postgres with password 'postgres';
    grant all privileges on database postgres to postgres;
    create extension pgcrypto;
    \q
    ```
 5. Add information about the new user to pg_hba.conf so the user can access the database. 
    ```
    echo 'local all postgres password' | sudo tee -a /usr/local/greenplum-db/master/gpsne-1/pg_hba.conf

    echo 'host all postgres 0.0.0.0/0 password' | sudo tee -a /usr/local/greenplum-db/master/gpsne-1/pg_hba.conf
    ```
 6. Restart Greenplum cluster.
    ```
    exit
    docker restart greenplumdb_singlenode
    ```
 7. Enter the Greenplum container as the gpadmin and start the Greenplum database.
    ```
    docker exec -it -u gpadmin greenplumdb_singlenode bash
    gpstart
    ```
 8. Test the connection to the Postgres database as the postgres user and create the schema 'sandbox' (optional).
    ```
    psql -U postgres -d postgres
    create schema sandbox;
    ```