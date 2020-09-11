'use strict';

const
	mapper = require('../util/neoMapper.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');

async function getArticlesWithTag(tagId) {
	const driver = getDriver();
	const s = driver.session();
	const query =
		`MATCH (article:Article)-[links:Tag]->(tag:Tag) WHERE tag.id = {tagId}
		RETURN tag, article, links`;
	const result = await runQuery(s)(query)({ tagId: tagId });
	driver.close();
	return mapper().map(result).toResult();
}


module.exports = getArticlesWithTag;
