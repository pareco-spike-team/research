'use strict';

const
	shortId = require('shortid'),
	getArticlesWithTag = require('./getArticlesWithTag.js'),
	{ getDriver, runQuery } = require('../util/neoHelper.js');


async function addTag(session, newTag, tagId) {
	const args = {
		tag: newTag,
		id: tagId
	};
	const addTagQuery = `MERGE (t:Tag { tag: {tag} }) ON CREATE SET t.id = {id} RETURN t`;

	await runQuery(session)(addTagQuery)(args);
}

async function addLinkToArticle(session, articleId, tagId) {
	const args = {
		articleId: articleId,
		tagId: tagId
	};
	const addTagQuery = `
		MATCH (a:Article) WHERE a.id = {articleId}
		MATCH (t:Tag) WHERE t.id = {tagId}
		MERGE (a)-[tag:Tag]->(t)
		RETURN a, tag, t
		`;

	await runQuery(session)(addTagQuery)(args);
}

async function addLinkToMatchingArticles(session, tagId, newTag) {
	const args = {
		tagId: tagId,
		tagMatch: `(?muis)${newTag}`
	};
	const tagArticles = `
		MATCH (a:Article) WHERE a.text =~ {tagMatch}
		MATCH (t:Tag) WHERE t.id = {tagId}
		MERGE (a)-[:Tag]->(t)
		RETURN count(a) AS articlesUpdated`;

	return await runQuery(session)(tagArticles)(args);
}

async function createTag(newTag, articleId, addToAllArticlesMatchingTag) {
	if (!newTag) { return false; }

	const tagId = shortId.generate();
	const driver = getDriver();
	try {
		const session = driver.session();
		await addTag(session, newTag, tagId);
		if (articleId) {
			addLinkToArticle(session, articleId, tagId);
		}
		if (addToAllArticlesMatchingTag) {
			addLinkToMatchingArticles(session, tagId, newTag);
		}

	} finally {
		driver.close();
	}

	return await getArticlesWithTag(tagId);
}

module.exports = createTag;
