'use strict';

const

	NEO_URL = "bolt://localhost:7689",
	NEO_USER = "neo4j",
	NEO_PWD = process.env.NEO_PWD || process.argv.slice(-1)[0],
	markdownFileToParse = `${__dirname}/../data/Galnet_Revamp_no_HTML.txt`,
	neo4j = require('neo4j-driver').v1,
	uuid = require('uuid/v4'),
	markdownParse = require('./markdownParser.js');


function getDriver() {
	const auth = neo4j.auth.basic(NEO_USER, NEO_PWD);
	const neo4jConfig = { connectionPoolSize: 10 };
	let driver = neo4j.driver(NEO_URL, auth, neo4jConfig);

	driver.onError = (e) => {
		console.error(e);
	};
	driver.onCompleted = () => {
	};

	return driver;
}

const fixTagCasing = t =>
	t.tag.
		split(' ').
		map(x => x.slice(0, 1).toUpperCase() + x.slice(1)).
		join(' ');

const caseInsensitiveRegexMatch = x => `(?i)${x.toLowerCase()}`;

async function saveTags(articles) {
	const tags = new Set();
	articles.forEach(a => {
		a.tags.forEach(t => {
			const s = fixTagCasing(t);
			tags.add(s);
			t.subTags.forEach(s => tags.add(fixTagCasing(s)));
		});
	});
	const driver = getDriver();
	let session = driver.session();
	for (const t of tags.values()) {
		let query = `
			MERGE (t:Tag { tag: {tag} }) RETURN t
		`;
		let args = {
			tag: t
		};
		try {
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	for (const a of articles) {
		for (const t of a.tags) {
			for (const s of t.subTags) {
				let query = `
					MATCH (t1:Tag) WHERE t1.tag =~ {t1}
					MATCH (t2:Tag) WHERE t2.tag =~ {t2}
					MERGE (t1)-[:Tag]->(t2)
					RETURN 0`;
				let args = {
					t1: caseInsensitiveRegexMatch(t.tag),
					t2: caseInsensitiveRegexMatch(s.tag)
				};
				try {
					await session.run(query, args);
				} catch (err) {
					console.error(err);
				}

			}
		}
	}
	driver.close();
}

async function saveArticles(articles) {
	console.log(`Saving ${articles.length} articles.`);
	const driver = getDriver();

	let session = driver.session();
	for (var article of articles) {
		let query = `
			CREATE (a:Article { id: {id}, title: {title}, text: {text}, date: {date} })
			WITH a`;
		let args = {
			id: uuid(),
			title: article.title.trim(),
			text: article.text.trim(),
			date: article.date
		};
		article.tags.forEach((tag, i) => {
			const tagQuery = `
				MATCH (t:Tag) WHERE t.tag =~ {tag${i}}
				MERGE (a)-[:Tag]->(t)
				WITH a
			`;
			query += tagQuery;
			args[`tag${i}`] = caseInsensitiveRegexMatch(tag.tag);
			tag.subTags.forEach((s, j) => {
				const subtagQuery = `
					MATCH (t:Tag) WHERE t.tag =~ {tag${i}_${j}}
					MERGE (a)-[:Tag]->(t)
					WITH a
				`;
				query += subtagQuery;
				args[`tag${i}_${j}`] = caseInsensitiveRegexMatch(s.tag);
			});
		});
		query += `
			RETURN 0`;
		try {
			await session.run(query, args);
		} catch (err) {
			console.error(err);
		}
	}

	driver.close();
}

function cleanTags(articles) {
	const cleanTagList = xs => {
		const cleaned = xs.
			map(x => ({ ...x, tag: x.tag.split(/\s+|\.|\?[,'"´`]/).join(' ').trim() })).
			filter(x => x.tag.length > 1);
		return [...new Set(cleaned)];
	};

	articles.forEach(a => {
		a.tags = cleanTagList(a.tags);
		a.tags.forEach(t => {
			t.subTags = cleanTagList(t.subTags);
		});
	});
}

async function addIndexes() {
	const q1 = 'CALL db.index.fulltext.createNodeIndex("TextTitleIndex", ["Article"],["text", "title"])';
	const q2 = 'CALL db.index.fulltext.createNodeIndex("TagIndex", ["Tag"],["tag"])';
	const driver = getDriver();
	let session = driver.session();
	await session.run(q1, {});
	await session.run(q2, {});
	driver.close();
}

const p = new Promise((resolve, reject) => {
	const articles = markdownParse(markdownFileToParse);
	cleanTags(articles);

	return saveTags(articles).
		then(() => saveArticles(articles)).
		then(() => addIndexes()).
		then(resolve).
		catch(reject);
});

p.
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});

