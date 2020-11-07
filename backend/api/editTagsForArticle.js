'use strict';

const
	shortId = require('shortid'),
	getTagsForArticle = require('./getTagsForArticle.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');

function buildQuery(actions) {
	return actions.
		map((x, idx) => {
			switch (x.action) {
				case "add":
					return `// Add one
						MERGE (t:Tag { tag: {tag_${idx}} }) ON CREATE SET t.id = {tagId_${idx}}
						WITH t
						MATCH (a:Article) WHERE a.id = {articleId}
						WITH a, t
						MERGE (a)-[:Tag]->(t)`;
				case "addAll":
					return `// Add all
						MERGE (t:Tag { tag: {tag_${idx}} }) ON CREATE SET t.id = {tagId_${idx}}
						WITH t
						MATCH (a:Article) WHERE a.text =~ {tagMatch_${idx}}
						MERGE (a)-[:Tag]->(t)`;
				case "delete":
					return `// Delete one
						MATCH (a:Article)-[tag:Tag]->(t:Tag)
						WHERE a.id = {articleId} AND t.id = {tagId_${idx}}
						DELETE tag
						//Delete tag when no relations left
						WITH 0 as x
						MATCH (t:Tag) WHERE NOT ((t)<-[:Tag]-(:Article)) DELETE t`;
				case "deleteAll":
					return `// Delete all
						MATCH (t:Tag) WHERE t.id = {tagId_${idx}}
						DETACH DELETE t`;
				default:
					throw new Error(`Unknown action ${x.action}`);
			}
		}).
		join('\nWITH 0 as x\n\n').
		replace(/\t+/g, '');
}

function buildArgs(articleId, actions) {
	return actions.reduce((acc, x, idx) => {
		switch (x.action) {
			case "add":
				acc[`tagId_${idx}`] = shortId.generate();
				acc[`tag_${idx}`] = x.value;
				break;
			case "addAll":
				acc[`tagId_${idx}`] = shortId.generate();
				acc[`tag_${idx}`] = x.value;
				acc[`tagMatch_${idx}`] = `(?mus).*${x.value}.*`;
				break;
			case "delete":
			case "deleteAll":
				acc[`tagId_${idx}`] = x.value;
		}
		return acc;
	}, { articleId: articleId });
}

async function editArticlesWithTag(articleId, actions) {
	const driver = getDriver();
	const s = driver.session();

	const query = buildQuery(actions);
	const args = buildArgs(articleId, actions);

	await runQuery(s)(query)(args);
	driver.close();
	const result = await getTagsForArticle(articleId, false);
	return result;
}


module.exports = editArticlesWithTag;
