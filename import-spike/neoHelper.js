'use strict';

const
	config = require('./config.js'),
	neo4j = require('neo4j-driver').v1;


function getDriver() {
	const auth = neo4j.auth.basic(config.neoUser, config.neoPassword);
	const neo4jConfig = { connectionPoolSize: 10 };
	let driver = neo4j.driver(config.neoUrl, auth, neo4jConfig);

	driver.onError = (e) => {
		console.error(e);
	};
	driver.onCompleted = () => {
	};

	return driver;
}

const getInt = i => {
	if (i == null) {
		return null;
	}
	let o = neo4j.int(i);
	return o.toNumber();
};

const runQuery = session => query => async args => {
	const result = await session.run(query, args);
	const objLookup = new Map();

	return result.records.map(record => {
		return record.keys.reduce((obj, key) => {
			const idx = record._fieldLookup[key];
			const value = record._fields[idx];
			if (value.identity != null) {
				const identity = getInt(value.identity);
				const label = value.labels[0];
				const lookupKey = `${label}.${identity}`;
				let objInstance = objLookup.get(lookupKey);
				if (objInstance == null) {
					objInstance = value.properties;
					objInstance.__meta = {
						label: label,
						identity: identity
					}
					objLookup.set(lookupKey, objInstance);
				}
				obj[key] = objInstance;
			} else {
				obj[key] = value;
			}
			return obj;
		}, {});
	});
};

module.exports = {
	getDriver: getDriver,
	runQuery: runQuery
};
