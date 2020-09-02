'use strict';


function mapToReturn(mapAcc, xs) {
	const result =
		xs.reduce((res, x) => {
			const match = res.get(x.article.id);
			if (match == null) {
				x.tags = [x.tag];
				delete x.tag;
				res.set(x.article.id, x);
			} else {
				match.tags = [...match.tags, x.tag];
			}
			return res;
		}, mapAcc);

	return result;
}

module.exports = mapToReturn;
