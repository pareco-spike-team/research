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

async function getAllTags() {
	const driver = getDriver();
	let session = driver.session();
	const query = runQuery(session);
	const findAllTagsQuery = `MATCH (t:Tag) RETURN t.tag as tag`;
	const result = (await query(findAllTagsQuery)({})).map(x => x.tag);
	driver.close();

	return result;
}

async function tagArticles() {
	const tags = await getAllTags();
	const driver = getDriver();
	let session = driver.session();
	const query = `
			MATCH (a:Article) WHERE a.text =~ {tagMatch} OR a.title =~ {tagMatch}
			MATCH (t:Tag) WHERE t.tag = {tag}
			MERGE (a)-[:Tag]->(t)
			RETURN count(a) AS articlesUpdated`;
	const addTag = runQuery(session)(query);
	console.log(`There are ${tags.length} to handle`);
	for (const tag of tags) {
		const args = { tag: tag, tagMatch: `(?muis).*${tag.toLowerCase()}.*` };
		const result = await addTag(args);
		console.log(`${result[0].articlesUpdated} articles has tag '${tag}'`);
	}
}

new Promise((resolve, reject) => {
	return tagArticles().
		then(resolve).
		catch(reject);
}).
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});

