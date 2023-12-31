// License: MPL-2.0
// (c) 2022 Drew DeVault <sir@cmpwn.com>
use hash::fnv;
use strings;

// TODO: Resize table as appropriate
export def OBJECT_BUCKETS: size = 32;

export type object = struct {
	buckets: [OBJECT_BUCKETS][](str, value),
	count: size,
};

// A JSON value.
export type value = (f64 | str | bool | _null | []value | object);

// Initializes a new (empty) JSON object. Call [[finish]] to free associated
// resources when you're done using it.
export fn newobject() object = {
	return object { ... };
};

// Gets a value from a JSON object. The return value is borrowed from the
// object.
export fn get(obj: *object, key: str) (*value | void) = {
	const hash = fnv::string(key);
	const bucket = &obj.buckets[hash % len(obj.buckets)];
	for (let i = 0z; i < len(bucket); i += 1) {
		if (bucket[i].0 == key) {
			return &bucket[i].1;
		};
	};
};

// Sets a value in a JSON object. The key and value will be duplicated.
export fn set(obj: *object, key: const str, val: const value) void = {
	const hash = fnv::string(key);
	const bucket = &obj.buckets[hash % len(obj.buckets)];
	for (let i = 0z; i < len(bucket); i += 1) {
		if (bucket[i].0 == key) {
			finish(bucket[i].1);
			bucket[i].1 = dup(val);
			return;
		};
	};
	obj.count += 1;
	append(bucket, (strings::dup(key), dup(val)));
};

// Deletes values from a JSON object, if they are present.
export fn del(obj: *object, keys: const str...) void = {
	for (let i = 0z; i < len(keys); i += 1) {
		const key = keys[i];
		const hash = fnv::string(key);
		const bucket = &obj.buckets[hash % len(obj.buckets)];
		for (let i = 0z; i < len(bucket); i += 1) {
			if (bucket[i].0 == key) {
				obj.count -= 1;
				free(bucket[i].0);
				finish(bucket[i].1);
				delete(bucket[i]);
				break;
			};
		};
	};
};

// Clears all values from a JSON object, leaving it empty.
export fn reset(obj: *object) void = {
	let it = iter(obj);
	for (true) match (next(&it)) {
	case void =>
		break;
	case let v: (const str, const *value) =>
		del(obj, v.0);
	};
};

// Returns the number of key/value pairs in a JSON object.
export fn count(obj: *object) size = {
	return obj.count;
};

export type iterator = struct {
	obj: *object,
	i: size,
	j: size,
};

// Creates an iterator that enumerates over the key/value pairs in an
// [[object]].
export fn iter(obj: *object) iterator = {
	return iterator { obj = obj, ... };
};

// Returns the next key/value pair from this iterator, or void if none remain.
export fn next(iter: *iterator) ((const str, const *value) | void) = {
	for (iter.i < len(iter.obj.buckets); iter.i += 1) {
		const bucket = &iter.obj.buckets[iter.i];
		for (iter.j < len(bucket)) {
			const key = bucket[iter.j].0;
			const val = &bucket[iter.j].1;
			iter.j += 1;
			return (key, val);
		};
		iter.j = 0;
	};
};

// Duplicates a JSON value. The caller must pass the return value to [[finish]]
// to free associated resources when they're done using it.
export fn dup(val: value) value = {
	match (val) {
	case let s: str =>
		return strings::dup(s);
	case let v: []value =>
		let new: []value = alloc([], len(v));
		for (let i = 0z; i < len(v); i += 1) {
			append(new, dup(v[i]));
		};
		return new;
	case let o: object =>
		let new = newobject();
		const i = iter(&o);
		for (true) {
			const pair = match (next(&i)) {
			case void =>
				break;
			case let pair: (const str, const *value) =>
				yield pair;
			};
			set(&new, pair.0, *pair.1);
		};
		return new;
	case =>
		return val;
	};
};

// Checks two JSON values for equality.
export fn equal(a: value, b: value) bool = {
	match (a) {
	case _null =>
		return b is _null;
	case let a: bool =>
		return b is bool && a == b as bool;
	case let a: f64 =>
		return b is f64 && a == b as f64;
	case let a: str =>
		return b is str && a == b as str;
	case let a: []value =>
		if (!(b is []value)) return false;
		const b = b as []value;
		if (len(a) != len(b)) return false;
		for (let i = 0z; i < len(a); i += 1) {
			if (!equal(a[i], b[i])) {
				return false;
			};
		};
		return true;
	case let a: object =>
		if (!(b is object)) return false;
		let b = b as object;
		if (count(&a) != count(&b)) {
			return false;
		};
		let a = iter(&a);
		for (true) match (next(&a)) {
		case let a: (const str, const *value) =>
			match (get(&b, a.0)) {
			case let b: *value =>
				if (!equal(*a.1, *b)) {
					return false;
				};
			case void => return false;
			};
		case void => break;
		};
		return true;
	};
};

// Frees state associated with a JSON value.
export fn finish(val: value) void = {
	match (val) {
	case let s: str =>
		free(s);
	case let v: []value =>
		for (let i = 0z; i < len(v); i += 1) {
			finish(v[i]);
		};
		free(v);
	case let o: object =>
		for (let i = 0z; i < len(o.buckets); i += 1) {
			const bucket = &o.buckets[i];
			for (let j = 0z; j < len(bucket); j += 1) {
				free(bucket[j].0);
				finish(bucket[j].1);
			};
			free(*bucket);
		};
	case => void;
	};
};
