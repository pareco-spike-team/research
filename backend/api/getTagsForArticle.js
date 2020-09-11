'use strict';

const
	mapper = require('../util/neoMapper.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');


async function getTagsForArticle(articleId, includeArticles) {
	const driver = getDriver();
	try {
		const s = driver.session();
		const query =
			`MATCH (article:Article)-[:Tag]->(tag:Tag) WHERE article.id = {articleId}
			WITH tag
			MATCH (tag)<-[links:Tag]-(article:Article) WHERE article.id = {articleId} OR article.id IN {includeArticles}
			RETURN tag, article, links`;
		const toInclude = includeArticles ? includeArticles.split(',').map(x => x.trim()) : [];

		const result = await runQuery(s)(query)({ articleId: articleId, includeArticles: toInclude });
		const mapResult = mapper().map(result).toResult();
		return mapResult;
	} finally {
		driver.close();
	}
}

module.exports = getTagsForArticle;
