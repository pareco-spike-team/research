'use strict';

const
	mapper = require('../backend/util/neoMapper.js'),
	{ getDriver, runQuery } = require('../backend/util/neoHelper');

async function getAllTags() {
	const driver = getDriver();
	let session = driver.session();
	const query = runQuery(session);
	const findAllTagsQuery = `MATCH (t:Tag) RETURN t as tag ORDER BY tag`;
	const result = await query(findAllTagsQuery)({});
	driver.close();

	return mapper().map(result).toResult().map(x => x.tag);
}

async function addSpecialTags() {
	const specialArticles = [
		{ match: `community goal`, tag: 'Community Goal', id: 'community_goal' },
		{ match: `freelance report`, tag: 'Freelance Report', id: 'freelance_report' },
		{ match: `a week in review'`, tag: 'Week in Review', id: 'week_in_review' },
		{ match: `a week in powerplay'`, tag: 'Week in Powerplay', id: 'week_in_powerplay' }
	];

	const driver = getDriver();
	for (const special of specialArticles) {
		let session = driver.session();
		await runQuery(`CREATE (t:Tag { id: {id}, tag: {tag}, specialExclude: true }) RETURN t`)(special);
		const query = `
			MATCH (t:Tag) WHERE t.id = {tagId}
			MATCH (a:Article) WHERE a.title =~ {match}
			MERGE (a)-[:Tag]->(t)
			RETURN count(a) AS articlesUpdated`;
		const args = {
			tagId: special.id,
			match: `(?muis)${special.match}.toLowerCase()}`
		};
		await runQuery(session)(query)(args);
		console.log(`Tagged '${special.match}'`);
	}
}

async function tagArticles() {
	const tags = await getAllTags();
	const driver = getDriver();
	let session = driver.session();
	const query = `
			MATCH (a:Article)
			WHERE (a.text =~ {tagMatch} OR a.title =~ {tagMatch})
				AND lower(a.title) <> 'week in review'
				AND (NOT lower(a.title) STARTS WITH 'community goal:')
				AND (NOT lower(a.title) STARTS WITH 'freelance report:')
				AND (NOT lower(a.title) STARTS WITH 'a week in powerplay')
			MATCH (t:Tag) WHERE t.tag = {tag}
			MERGE (a)-[:Tag]->(t)
			RETURN count(a) AS articlesUpdated`;
	const addTag = runQuery(session)(query);
	console.log(`There are ${tags.length} to handle`);
	for (const tag of tags) {
		const args = { tag: tag, tagMatch: `(?muis).*[^a-z]${tag.toLowerCase()}[^a-z].*` };
		await addTag(args);
		console.log(`tag '${tag}'`);
	}
}

new Promise((resolve, reject) => {
	return tagArticles().
		then(addSpecialTags).
		then(resolve).
		catch(reject);
}).
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});

