'use strict';

const
	{ getDriver, runQuery } = require('../../util/neoHelper.js');

async function searchByTag(filter) {
	const driver = getDriver();
	const s = driver.session();
	const tagMatch = filter ? `(?muis)${filter}` : null;
	const query = filter ?
		"MATCH (tag:Tag) WHERE tag.tag =~ {tag} RETURN tag ORDER BY tag.tag" :
		"MATCH (tag:Tag) RETURN tag ORDER BY tag.tag";
	const result = await runQuery(s)(query)({ tag: tagMatch });
	driver.close();
	return result;
}

module.exports = searchByTag;
