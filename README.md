# TODO: put stuff here

## Pre-reqs

- nodejs (probably 10.something would do)
- yarn
- docker

## Howto run

- `$ yarn install`
- `$ yarn build`
- `$ docker-compose up -d`
- browse to http://localhost:7476/browser
- database is at `bolt://localhost:7689`
- login: neo4j / neo4j . You need to pick a password first time you connect.
- to import data run `sh ./import.sh neo4j_password_here`
- start server with `node backend/express/server.js "neo4j_password_here"`
- open browser and goto `http://localhost:8088/`
