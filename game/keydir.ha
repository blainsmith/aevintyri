use hash::fnv;

// 64 buckets of slices of (str, *meta) tuples
export type keydir = [64][](str, *game::area);

fn keydir_get(kd: *keydir, key: str) (*meta | void) = {
	let bkt = fnv::string(key) % len(kd);
	for (let i = 0z; i < len(kd[bkt]); i += 1) {
		if (kd[bkt][i].0 == key) {
			return kd[bkt][i].1;
		};
	};
	return;
};

fn keydir_set(kd: *keydir, key: str, val: *game::area) void = {
	let bkt = fnv::string(key) % len(kd);
	for (let i = 0z; i < len(kd[bkt]); i += 1) {
		if (kd[bkt][i].0 == key) {
			kd[bkt][i].1 = val;
			return;
		};
	};
	append(kd[bkt], (key, val));
	return;
};

fn keydir_del(kd: *keydir, key: str) void = {
	let bkt = fnv::string(key) % len(kd);
	for (let i = 0z; i < len(kd[bkt]); i += 1) {
		if (kd[bkt][i].0 == key) {
			delete(kd[bkt][i]);
			return;
		};
	};
	return;
};

fn keydir_finish(kd: *keydir) void = {
	for (let i = 0z; i < len(kd); i += 1) {
		free(kd[i]);
	};
};