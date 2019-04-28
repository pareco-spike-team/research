# TODO: put stuff here

## Neo4j database

* Run docker-compose up -d
* browse to http://localhost:7476/browser
* database is at `bolt://localhost:7689`
* login: neo4j / neo4j . You need to pick a password first time you connect.
* to import data run `sh ./import.js neo4j_password_here`
* start server with `node server/server.js neo4j_password_here`
* open browser and goto `http://localhost:8086/`
