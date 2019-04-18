'use strict';

const
	NEO_URL = "bolt://localhost:7689",
	NEO_USER = "neo4j",
	NEO_PWD = process.env.NEO_PWD || process.argv.slice(-1)[0],
	neo4j = require('neo4j-driver').v1;


function getDriver() {
	const auth = neo4j.auth.basic(NEO_USER, NEO_PWD);
	const neo4jConfig = { connectionPoolSize: 10 };
	let driver = neo4j.driver(NEO_URL, auth, neo4jConfig);

	driver.onError = (e) => {
		console.error(e);
	};
	driver.onCompleted = () => {
	};

	return driver;
}

const runQuery = session => query => async args => {
	const result = await session.run(query, args);

	return result.records.map(record => {
		return record.keys.reduce((obj, key) => {
			const idx = record._fieldLookup[key];
			const value = record._fields[idx];
			obj[key] = value;
			return obj;
		}, {});
	});
};

module.exports = {
	getDriver: getDriver,
	runQuery: runQuery
};
