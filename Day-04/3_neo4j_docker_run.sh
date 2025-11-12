#! /bin/bash

docker run -d \
    --name neo4j-sds-class \
    --publish=7474:7474 \
    --publish=7687:7687 \
    --volume=./plugins:/plugins \
    --volume=./data:/data \
    --env NEO4J_dbms_security_procedures_unrestricted=apoc.meta.*,apoc.* \
    --env NEO4JLABS_PLUGINS='["apoc"]' \
    neo4j:5.24.2-community
