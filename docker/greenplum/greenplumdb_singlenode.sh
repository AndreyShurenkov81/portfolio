#!/bin/sh
# Author: Andrey Shurenkov

echo ----------------------------
echo Create a sandbox network.
echo ----------------------------
docker network create sandbox

echo ----------------------------
echo GREENPLUMDB SINGLENODE
echo ----------------------------

IMAGE_NAME="greenplumdb:6.25.3"

echo Check if the image exists and create it if not.
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "The $IMAGE_NAME was not found. Creating the image"
    sh ./images/create.sh
fi

echo Create and run the Greenplum container.
docker run -it --network sandbox --hostname greenplumdb_singlenode --name greenplumdb_singlenode -p 5434:5432 -d greenplumdb:6.25.3

echo Create the folder /usr/local/greenplum-db/segments in the Greenplum container.
docker exec -it -u gpadmin greenplumdb_singlenode bash -c "mkdir -p /usr/local/greenplum-db/segments"

echo Create the folder /usr/local/greenplum-db/master in the Greenplum container.
docker exec -it -u gpadmin greenplumdb_singlenode bash -c "mkdir -p /usr/local/greenplum-db/master"

echo Copy the file gpinitsystem_singlenode from the local maсhine into greenplumdb_singlenode:/usr/local/greenplum-db.
docker cp ./settings/usr/local/greenplum-db/gpinitsystem_singlenode greenplumdb_singlenode:/usr/local/greenplum-db && docker exec -u root greenplumdb_singlenode /bin/bash -c "chown gpadmin:gpadmin /usr/local/greenplum-db/gpinitsystem_singlenode"

echo Copy the file gpinitsystem_singlenode from the local maсhine into greenplumdb_singlenode:/usr/local/greenplum-db.
docker cp ./settings/usr/local/greenplum-db/host_singlenode greenplumdb_singlenode:/usr/local/greenplum-db && docker exec -u root greenplumdb_singlenode /bin/bash -c "chown gpadmin:gpadmin /usr/local/greenplum-db/host_singlenode"

echo Manually execute the actions described in the Readme.md file.