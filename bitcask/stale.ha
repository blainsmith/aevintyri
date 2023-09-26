use io;

export type stale = [64][](size, *datafile);

fn stale_get(s: *stale, key: size) (*datafile | void) = {
	let bkt = key % len(s);
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
			return s[bkt][i].1;
		};
	};
	return;
};

fn stale_set(s: *stale, key: size, val: *datafile) void = {
	let bkt = key % len(s);
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
			s[bkt][i].1 = val;
			return;
		};
	};
	append(s[bkt], (key, val));
	return;
};

fn stale_del(s: *stale, key: size) void = {
	let bkt = key % len(s);
	for (let i = 0z; i < len(s[bkt]); i += 1) {
		if (s[bkt][i].0 == key) {
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