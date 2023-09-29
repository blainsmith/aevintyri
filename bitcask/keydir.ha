use endian;
use errors;
use fs;
use hash::fnv;
use io;
use log;
use memio;
use os;
use strings;
use time;

export type meta = struct {
	ts: time::instant,
	recsz: size,
	recpos: size,
	fid: i64,
};

export type keydir = [64][](str, *meta);

fn keydir_get(kd: *keydir, key: str) (*meta | void) = {
	let bkt = fnv::string(key) % len(kd);
	for (let i = 0z; i < len(kd[bkt]); i += 1) {
		if (kd[bkt][i].0 == key) {
			return kd[bkt][i].1;
		};
	};
	return;
};

fn keydir_set(kd: *keydir, key: str, val: *meta) void = {
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

@test fn keydir_set_get_del() void = {
	let kd: keydir = [[]...];
	defer keydir_finish(&kd);

	keydir_set(&kd, "key1", &meta { fid = 1, ... });

	let m = keydir_get(&kd, "key1"): *meta;
	assert(m.fid == 1);

	keydir_del(&kd, "key1");

	let m2 = keydir_get(&kd, "key1");
	assert(m2 is void);
};


fn keydir_encode(kd: *keydir, w: io::handle) (void | io::error) = {
	for (let bkt = 0z; bkt < len(kd); bkt += 1) {
		for (let i = 0z; i < len(kd[bkt]); i += 1) {
			let klen: [2]u8 = [0...];
			endian::little.putu16(klen, len(kd[bkt][i].0): u16);
			io::write(w, klen[0..])?;
			
			io::write(w, strings::toutf8(kd[bkt][i].0))?;

			let ts: [8]u8 = [0...];
			endian::little.putu64(ts, unixnano(kd[bkt][i].1.ts): u64);
			io::write(w, ts[0..])?;

			let recsz: [2]u8 = [0...];
			endian::little.putu16(recsz, kd[bkt][i].1.recsz: u16);
			io::write(w, recsz[0..])?;

			let recpos: [2]u8 = [0...];
			endian::little.putu16(recpos, kd[bkt][i].1.recpos: u16);
			io::write(w, recpos[0..])?;

			let fid: [8]u8 = [0...];
			endian::little.putu64(fid, kd[bkt][i].1.fid: u64);
			io::write(w, fid[0..])?;
		};
	};
};

fn keydir_decode(kd: *keydir, r: io::handle) (void | io::error) = {
	for (true) {
		let m = alloc(meta { ... });

		let klenbuf: [2]u8 = [0...];
		if (io::read(r, klenbuf[..])? is io::EOF) {
			break;
		};
		let klen = endian::little.getu16(klenbuf);

		let key: []u8 = alloc([0...], klen);
		if (io::read(r, key)? is io::EOF) {
			return errors::invalid;
		};

		let tsbuf: [8]u8 = [0...];
		if (io::read(r, tsbuf[..])? is io::EOF) {
			return errors::invalid;
		};
		m.ts = from_unixnano(0, endian::little.getu64(tsbuf): i64);

		let recszbuf: [2]u8 = [0...];
		if (io::read(r, recszbuf[..])? is io::EOF) {
			return errors::invalid;
		};
		m.recsz = endian::little.getu16(recszbuf): size;

		let recposbuf: [2]u8 = [0...];
		if (io::read(r, recposbuf[..])? is io::EOF) {
			return errors::invalid;
		};
		m.recpos = endian::little.getu16(recposbuf): size;

		let fidbuf: [8]u8 = [0...];
		if (io::read(r, fidbuf[..])? is io::EOF) {
			return errors::invalid;
		};
		m.fid = endian::little.getu64(fidbuf): i64;

		keydir_set(kd, strings::fromutf8_unsafe(key), m);
	};
};

@test fn keydir_encode_decode() void = {
	// create an in-memory buffer to represent a file
	let kdf = memio::dynamic();

	// create a new keydir and fill it with some keys and meta
	let kd: keydir = [[]...];
	keydir_set(&kd, "key1", &meta {
		ts = time::now(time::clock::REALTIME),
		recsz = 3z,
		recpos = 10z,
		fid = 1i64,
	});
	keydir_set(&kd, "this is a longer key", &meta {
		ts = time::now(time::clock::REALTIME),
		recsz = 10z,
		recpos = 5z,
		fid = 10i64,
	});

	// encode the keydir to the in-memory file
	keydir_encode(&kd, &kdf: io::handle)!;

	// move the read cursor to the beginning of the file
	// to simulate opening a file of encoded keys/meta fresh
	// with data
	io::seek(&kdf, 0, io::whence::SET)!;

	// create another new keydir
	let kdnew: keydir = [[]...];

	// decode the in-memory file into the new keydir
	keydir_decode(&kdnew, &kdf: io::handle)!;

	// check the decoded keydir has the key we expected
	let m = keydir_get(&kdnew, "key1"): *meta;
	assert(m.recsz == 3z);
	assert(m.recpos == 10z);
	assert(m.fid == 1i64);
};