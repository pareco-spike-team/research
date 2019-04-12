#!/bin/bash
docker-compose down
if [ -d ~/data/galnetpedia-neo/databases ]; then
  rm -rf ~/data/galnetpedia-neo/databases
fi
docker-compose up -d
# wait for neo to start up
sleep 10
node ./import.js $@
