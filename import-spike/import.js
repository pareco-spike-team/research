'use strict';

const
	NEO_URL = "bolt://localhost:7689",
	NEO_USER = "neo4j",
	NEO_PWD = process.env.NEO_PWD || process.argv.slice(-1)[0],
	neo4j = require('neo4j-driver').v1,
	uuid = require('uuid/v4'),
	fs = require('fs');
/*
	How to interpret the markdown
	# - article title
	## - tag on article
	### subtag
	* Also tag ?
*/


function parse() {
	const content = ("" + fs.readFileSync(`${__dirname}/../data/Galnet_Revamp_no_HTML.txt`));
	const rows = content.split('\n');

	const parsedArticles =
		rows.reduce((articles, row) => {
			const trimmedRow = row.trim();
			const isSubTag = trimmedRow.startsWith('###');
			const isTag = !isSubTag && trimmedRow.startsWith('##');
			const isTitle = !isTag && trimmedRow.startsWith('#');
			const isStar = trimmedRow.startsWith('* ');
			if (isSubTag) {
				const tag = trimmedRow.slice(3).trim();
				const parent = articles.current.tags.slice(-1)[0];
				parent.subTags.push({ tag: tag });
				//articles.current.tags.push(tag);
				// articles.current.tags.push({ tag: trimmedRow.slice(2).trim(), subTags: [] });
			} else if (isTag) {
				articles.current.tags.push({ tag: trimmedRow.slice(2).trim(), subTags: [] });
			} else if (isTitle) {
				articles.current = {
					title: trimmedRow.slice(1).trim(),
					text: '',
					tags: []
				};
				articles.all.push(articles.current);
			} else if (!isStar) {
				if (/^\d{4}-\d{2}-\d{2}$/.test(trimmedRow)) {
					articles.current.date = trimmedRow;
				} else {
					articles.current.text = `${articles.current.text}\n${trimmedRow}`;
				}
			}

			return articles;
		}, { current: null, all: [] });

	return parsedArticles.all;
}

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

async function saveTags(articles) {
	const tags = new Set();
	articles.forEach(a => {
		a.tags.forEach(t => {
			tags.add(t.tag);
			t.subTags.forEach(s => tags.add(s.tag));
		});
	});
	const driver = getDriver();
	let session = driver.session();
	for (const t of tags.values()) {
		let query = `
			MERGE (t:Tag { tag: {tag} }) RETURN t`;
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
					MATCH (t1:Tag) WHERE t1.tag = {t1}
					MATCH (t2:Tag) WHERE t2.tag = {t2}
					MERGE (t1)-[:Tag]->(t2)
					RETURN 0`;
				let args = {
					t1: t.tag,
					t2: s.tag
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
			title: article.title,
			text: article.text,
			date: article.date
		};
		article.tags.forEach((tag, i) => {
			const tagQuery = `
				MATCH (t:Tag) WHERE t.tag = {tag${i}}
				MERGE (a)-[:Tag]->(t)
				WITH a
			`;
			query += tagQuery;
			args[`tag${i}`] = tag.tag;
			tag.subTags.forEach((s, j) => {
				const subtagQuery = `
					MATCH (t:Tag) WHERE t.tag = {tag${i}_${j}}
					MERGE (a)-[:Tag]->(t)
					WITH a
				`;
				query += subtagQuery;
				args[`tag${i}_${j}`] = s.tag;
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

const articles = parse();
const p = new Promise((resolve, reject) => {
	return saveTags(articles).
		then(() => saveArticles(articles)).
		then(resolve).
		catch(reject);
});

p.
	then(() => setTimeout(process.exit, 0)).
	catch(err => {
		console.error(err);
		setTimeout(process.exit, 1);
	});

