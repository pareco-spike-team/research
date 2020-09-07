'use strict';

module.exports = async (action) => {
	try {
		const result = await action();
		return {
			statusCode: 200,
			body: JSON.stringify(result)
		};
	} catch (err) {
		console.error(err);

		return {
			statusCode: 500,
			body: "",
		};
	}

}
