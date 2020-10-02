'use strict';


const
	mapper = require('../util/neoMapper.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');


module.exports = async (userName, from, to) => {
	const driver = getDriver();
	try {
		const s = driver.session();

		const args = {
			fromId: from,
			toId: to
		};
		const query =
			`MATCH (article:Article)-[links:Tag]->(tag:Tag)
			WHERE article.id = {fromId} AND tag.id = {toId}
			REMOVE links.color_${userName}
			RETURN article, tag, links`;

		const result = await runQuery(s)(query)(args);
		return mapper().map(result).toResult();
	} finally {
		driver.close();
	}
};
