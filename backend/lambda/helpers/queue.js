'use strict';

const
	AWS = require('./aws.js');

const sqs = (config, queueName) => {
	const
		queue = new AWS.SQS(),
		queueUrl = (() => {
			const awsRegion = config.aws.region;
			const awsAccount = config.aws.account;
			const awsQueueName = config.queue[queueName];
			return `https://sqs.${awsRegion}.amazonaws.com/${awsAccount}/${awsQueueName}`;
		})();

	const createMsg = (msg, delay = 0) => {
		return {
			DelaySeconds: delay,
			MessageBody: JSON.stringify(msg),
		};
	};

	const sendMessageBatch = async (messages, delay) => {
		const params = {
			Entries: messages.map((msg, i) => ({ ...createMsg(msg, delay), Id: `${i}` })),
			QueueUrl: queueUrl
		};

		const res = await queue.sendMessageBatch(params).promise();
		return res;
	};

	return {
		sendMessageBatch: sendMessageBatch
	};
};

const file = (queueName) => {
	const
		Path = require('path'),
		FS = require('fs');
	const createDir = (dir) => {
		try {
			FS.mkdirSync(dir, { recursive: true });
		} catch (err) { }
	};
	return {
		sendMessageBatch: (xs) => {
			const dir = Path.join(`${Path.dirname(__dirname)}`, '..', '.queue_msgs', queueName);
			createDir(dir);
			let count = 0;
			for (let x of xs) {
				const fileName = Path.join(dir, `${Date.now()}_${count++}.json`);
				FS.writeFileSync(fileName, JSON.stringify(x));
			}
			return Promise.resolve();
		}
	};
};

const getQueue = (config, queueName) => {
	switch (config.env) {
		case 'dev': return file(queueName);
		case 'production': return sqs(config, queueName);
		default: return null;
	}
};

module.exports = (config) => {
	return {
		galnetArticleUpdate: getQueue(config, 'galnetArticleUpdate')
	};
};
