#!/bin/bash
docker-compose down
if [ -d ~/data/galnetpedia-neo/databases ]; then
  rm -rf ~/data/galnetpedia-neo/databases
fi
docker-compose up -d
# wait for neo to start up
echo =Waiting for neo to startup =
sleep 12
echo = Importing data =
cd dataImport
node ./import.js $@
echo = Update tags on articles =
node ./updateArticleTags.js $@
node ./galnetUpdate.js $@
