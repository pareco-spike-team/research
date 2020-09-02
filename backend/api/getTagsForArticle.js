'use strict';

const
	mapToReturn = require('./helper/mapToReturn.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');


async function getTagsForArticle(articleId, includeArticles) {
	const driver = getDriver();
	try {
		const s = driver.session();
		const query =
			`MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE article.id = {articleId} WITH tag
		MATCH (tag)<-[:Tag]-(article:Article) WHERE article.id = {articleId} OR article.id IN {includeArticles} RETURN tag, article`;
		const toInclude = includeArticles ? includeArticles.split(',').map(x => x.trim()) : [];

		const result = await runQuery(s)(query)({ articleId: articleId, includeArticles: toInclude });
		const mapResult = mapToReturn(new Map(), result);
		return [...mapResult.values()];
	} finally {
		driver.close();
	}
}

module.exports = getTagsForArticle;
