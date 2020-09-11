'use strict';

const
	neo4j = require('neo4j-driver').v1;

const isInt = (neoObj) => {
	return neoObj.hasOwnProperty('low') && neoObj.hasOwnProperty('high');
};

const neoIntToInt = i => {
	if (i == null) {
		return null;
	}
	let o = neo4j.int(i);
	return o.toNumber();
};

const typeHandlers = [
	{ is: neoObj => neo4j.isInt(neoObj) || isInt(neoObj), map: neoIntToInt },
	{ is: neoObj => typeof (neoObj) === 'string', map: x => x }
];

const mapObject = (neoObj) => {
	const handler = typeHandlers.find(f => f.is(neoObj));
	if (handler) {
		return handler.map(neoObj);
	} else if (Array.isArray(neoObj)) {
		return neoObj.map(mapObject);
	} else {
		let data = neoObj.properties ? neoObj.properties : neoObj;
		let o = Object.getOwnPropertyNames(data).
			reduce((obj, p) => {
				let value = data[p];
				obj[p] = (value && typeof (value) === 'object') ? mapObject(value) : value;
				return obj;
			}, {});
		return o;
	}
};

const mapLink = (neoObj) => {
	const type = neoObj.type;
	const from = neoIntToInt(neoObj.start);
	const to = neoIntToInt(neoObj.end);
	const properties = mapObject(neoObj);
	const props =
		Object.keys(properties).
			reduce((o, p) => {
				const _p = p.split('_')[0];
				o[_p] = properties[p];
				return o;
			}, {});
	return { _meta: { type, label: "Link", from, to }, ...props };
};

const toResult = mapAcc => {
	return [...mapAcc.values()].
		map(x => {
			if (x._meta.type === "Tag") {
				const from = mapAcc.get(x._meta.from);
				x._meta.from = from.id;
				const to = mapAcc.get(x._meta.to);
				x._meta.to = to.id;
			}
			return x;
		});
};

const mapNeoData = () => {
	const mapAcc = new Map();
	const map = neoData => {
		neoData.forEach(item => {
			item.keys.forEach(key => {
				const idx = item._fieldLookup[key];
				const neoObj = item._fields[idx];
				const _identity = neoIntToInt(neoObj.identity);
				const isLink = neoObj.type != null;
				if (isLink) {
					const link = mapLink(neoObj);
					mapAcc.set(`${link._meta.type}.${_identity}`, link);
				} else {
					const label = neoObj.labels[0];
					const x = mapObject(neoObj);
					const o = { _meta: { type: "Label", label }, ...x };
					mapAcc.set(_identity, o);
				}
			});
		});

		return {
			map: map,
			toResult: () => toResult(mapAcc)
		};
	};

	return { map };
};


module.exports = mapNeoData;
