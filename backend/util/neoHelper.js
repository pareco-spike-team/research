'use strict';

const
	config = require('../../config.js'),
	neo4j = require('neo4j-driver').v1;

function getDriver() {
	const auth = neo4j.auth.basic(config.neo.user, config.neo.password);
	const neo4jConfig = { connectionPoolSize: 10 };
	let driver = neo4j.driver(config.neo.url, auth, neo4jConfig);

	driver.onError = (e) => {
		console.error(e);
	};
	driver.onCompleted = () => {
	};

	return driver;
}

const runQuery = session => query => async args => {
	const result = await session.run(query, args);

	return result.records;
};

module.exports = {
	getDriver: getDriver,
	runQuery: runQuery
};
