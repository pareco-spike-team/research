'use strict';

const
	config = require('../../../config.js'),
	request = require('request-promise-native'),
	queue = require('../helpers/queue.js')(config).galnetArticleUpdate;

function groupsOf(array, sliceSize) {
	const sliced = array.reduce((acc, x) => {
		const last = () => acc.slice(-1)[0];
		if (last().length >= sliceSize) {
			acc.push([]);
		}
		last().push(x);
		return acc;
	}, [[]]);

	return sliced.filter(x => x.length > 0);
}

async function getArticles(request) {
	const
		uri = "https://elitedangerous-website-backend-production.elitedangerous.com/api/galnet?_format=json",
		query = { uri: uri };

	const items = JSON.parse(await request(query));

	return items.
		filter(x => x.slug !== "adder-ship-kit");
}

async function run(event) {
	try {

		const articles = await getArticles(request);
		const groupsOfArticles = groupsOf(articles, 70);
		for (let group of groupsOfArticles) {
			await queue.sendMessageBatch([group]);
		}
		return { message: 'function execution success!', event };
	} catch (err) {
		console.error('GalnetArticleFetch failed to handle event', { event: event, err: err });
		return { message: 'function execution failed!', event: event, err: err.stack || err };
	}
}

exports.run = run;

/*
run().
	then(() => process.exit(0)).
	catch(err => {
		console.error(err);
		process.exit(1);
	});
*/
