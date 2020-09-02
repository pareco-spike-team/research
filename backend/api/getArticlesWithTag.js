'use strict';

const
	mapToReturn = require('./helper/mapToReturn.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');

async function getArticlesWithTag(tagId) {
	const driver = getDriver();
	const s = driver.session();
	const query =
		"MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE tag.id = {tagId} RETURN tag, article";
	const result = await runQuery(s)(query)({ tagId: tagId });
	driver.close();
	return [...mapToReturn(new Map(), result).values()];
}


module.exports = getArticlesWithTag;
