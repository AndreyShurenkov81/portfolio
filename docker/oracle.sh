#!/bin/sh
# Author: Andrey Shurenkov

echo ----------------------------
echo Create a sandbox network.
echo ----------------------------
docker network create sandbox

echo ----------------------------
echo ORACLE21XE
echo ----------------------------

echo Create and run the oracle21xe container.
docker run --name oracle21xe --network sandbox  -p 1521:1521 -p 5500:5500 -e ORACLE_PWD=sys -d container-registry.oracle.com/database/express:21.3.0-xe

echo Wait for the services in the container to run for one minute.
sleep 60

echo Create user 'sandbox'
docker exec -it oracle21xe sh -c "echo 'CREATE USER sandbox IDENTIFIED BY sandbox123 DEFAULT TABLESPACE users QUOTA UNLIMITED ON users TEMPORARY TABLESPACE temp;' | sqlplus sys/sys@XEPDB1 as sysdba"

echo Grant the privileges to user 'sandbox'
docker exec -it oracle21xe sh -c "echo 'GRANT CONNECT, RESOURCE TO sandbox;' | sqlplus sys/sys@XEPDB1 as sysdba"

echo Stop the oracle21xe container. 
docker stop oracle21xe