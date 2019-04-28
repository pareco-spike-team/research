'use strict';

const
	{ getDriver, runQuery } = require('../util/neoHelper');

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

