'use strict';


const
	mapper = require('../util/neoMapper.js'),
	{ getDriver, runQuery, int } = require('../util/neoHelper.js');


module.exports = async (userName, from, to, color) => {
	const driver = getDriver();
	try {
		const s = driver.session();

		const args = {
			fromId: from,
			toId: to,
			color: color.map(x => int(x))
		};
		const query =
			`MATCH (article:Article)-[links:Tag]->(tag:Tag)
			WHERE article.id = {fromId} AND tag.id = {toId}
			SET links.color_${userName} = {color}
			RETURN article, tag, links`;

		const result = await runQuery(s)(query)(args);
		return mapper().map(result).toResult();
	} finally {
		driver.close();
	}
};
