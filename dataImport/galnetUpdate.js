'use strict';

const
	{ getDriver, runQuery } = require('../util/neoHelper'),
	request = require('request-promise-native'),
	shortId = require('shortid'),
	moment = require('moment');

const uri = "https://elitedangerous-website-backend-production.elitedangerous.com/api/galnet?_format=json";

async function getAllTags() {
	const driver = getDriver();
	let session = driver.session();
	const query = runQuery(session);
	const findAllTagsQuery = `MATCH (t:Tag) RETURN t.tag as tag ORDER BY tag`;
	const result = (await query(findAllTagsQuery)({})).map(x => x.tag);
	driver.close();

	return result;
}

async function saveArticles(articles) {
	console.log(`Saving ${articles.length} articles.`);
	const driver = getDriver();

	let session = driver.session();
	for (var article of articles) {
		let query = `
			MERGE (a:Article { title: {title}, date: {date} })
			ON CREATE SET a.id = {id}, a.text = {text}
			WITH a`;
		let args = {
			id: article.id,
			title: article.title.trim(),
			text: article.text.trim(),
			date: article.date
		};
		article.tags.forEach((tag, i) => {
			const tagQuery = `
				MATCH (t:Tag) WHERE t.tag = {tag${i}}
				MERGE (a)-[:Tag]->(t)
				WITH a
			`;
			query += tagQuery;
			args[`tag${i}`] = tag;
		});
		query += `
			RETURN 0`;
		try {
			console.log(`${article.date} ${article.title} (${article.id})`);
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	driver.close();
}


async function readFeed() {
	const tags = await getAllTags();
	const tagRegexes = tags.map(x => {
		return { tag: x, regex: new RegExp(`[^a-z]${x.toLowerCase()}[^a-z]`, "muisg") };
	});
	const query = { uri: uri };
	const items = JSON.parse(await request(query));
	const articles =
		items.
			filter(x => x.slug !== "adder-ship-kit").
			map(x => {
				return {
					id: `${x.nid}_${shortId.generate()}`,
					title: x.title.trim(),
					text: x.body.replace(/<p>/, '').replace(/<br \/>/g, '\n').replace(/<\/p>/, '').trim(),
					date: moment(x.date).format("YYYY-MM-DD"),
					tags: []
				};
			}).
			map(x => {
				x.tags = tagRegexes.filter(t => t.regex.test(x.text)).map(t => t.tag);
				return x;
			});

	console.log(`${articles.length} articles to save.`);
	await saveArticles(articles);
}


readFeed().
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});
