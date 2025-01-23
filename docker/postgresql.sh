#!/bin/sh
# Author: Andrey Shurenkov

echo ----------------------------
echo Create a sandbox network.
echo ----------------------------
docker network create sandbox

echo ----------------------------
echo POSTGRESQL
echo ----------------------------
echo Create and run the PostgreSQL container.
docker run --name postgres --network sandbox  -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d postgres

echo Download the demo database archive.
curl -O https://edu.postgrespro.ru/demo-big-20161013.zip

echo Extract the archive.
tar -xvf demo-big-20161013.zip

echo Remove the archive from the local machine.
rm demo-big-20161013.zip

echo Copy the script from the local machine to the PostgreSQL container.
docker cp demo_big.sql postgres:/tmp

echo Remove the script from the local machine.
rm demo_big.sql

echo Execute the demo_big.sql script in the PostgreSQL container.
docker exec --workdir /tmp postgres psql -U postgres -f demo_big.sql

echo Remove the script from the PostgeSQL container.
docker exec --workdir /tmp postgres rm demo_big.sql

echo Follow these steps to access the objects of the demo database.
echo 1. Create extension postgres_fdw
docker exec -it postgres psql -U postgres -c 'create extension postgres_fdw;'

echo 2. Create foreign server to access the demo database.
docker exec -it postgres psql -U postgres -c "create server demo foreign data wrapper postgres_fdw options (host 'localhost', dbname 'demo', port '5432');"

echo 3. Create schema 'demo_bookings'.
docker exec -it postgres psql -U postgres -c 'create schema demo_bookings;'

echo 3. Create a user mapping.
docker exec -it postgres psql -U postgres -c "create user mapping for postgres server demo options (user 'postgres', password 'postgres');"

echo 4. Import the foreign schema 'bookings' from the server 'demo' into the schema 'demo_bookings'.
docker exec -it postgres psql -U postgres -c 'import foreign schema bookings from server demo into demo_bookings;'

echo Create extension pgcrypto in the postgres database.
docker exec -it postgres psql -U postgres -c 'create extension pgcrypto;'

echo Create schema 'sandbox'.
docker exec -it postgres psql -U postgres -c 'create schema sandbox;'

echo Stop the PostgreSQL container.
docker stop postgres