use io;

export type stale = [64][](i64, *datafile);

fn stale_keys(s: *stale) ([]i64 | void) = {
	let keys = []: []i64;

	for (let bkt = 0z; bkt < len(s); bkt += 1) {
		for (let i = 0z; i < len(s[bkt]); i += 1) {
			append(keys, s[bkt][i].0);
		};
	};

	return keys;
};

fn stale_get(s: *stale, key: i64) (*datafile | void) = {
	let bkt = key % len(s): i64;
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
			return s[bkt][i].1;
		};
	};
	return;
};

fn stale_set(s: *stale, key: i64, val: *datafile) void = {
	let bkt = key % len(s): i64;
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
			s[bkt][i].1 = val;
			return;
		};
	};
	append(s[bkt], (key, val));
	return;
};

fn stale_del(s: *stale, key: i64) void = {
	let bkt = key % len(s): i64;
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
			datafile_finish(s[bkt][i].1)!;
			delete(s[bkt][i]);
			return;
		};
	};
	return;
};

fn stale_finish(s: *stale) void = {
	for (let bkt = 0z; bkt < len(s); bkt += 1) {
		for (let i = 0z; i < len(s[bkt]); i += 1) {
			datafile_finish(s[bkt][i].1)!;
		};
	};
};
