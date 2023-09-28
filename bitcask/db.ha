use errors;
use fmt;
use fs;
use glob;
use hash;
use hash::crc32;
use io;
use log;
use os;
use sort;
use sort::cmp;
use strconv;
use strings;
use temp;
use time;

def DATAFILE: str = "{}.bitcask.data";
def HINTFILE: str = "{}.bitcask.hint";

export type opts = struct {
	dir: str,
	maxfilesz: size,
	sync: time::duration,
	compaction: time::duration,
	sizecheck: time::duration,
};

export let defaultopts = opts {
	dir = ".",
	maxfilesz = (1 << 32): size,
	sync = time::MINUTE,
	compaction = 6 * time::HOUR,
	sizecheck = time::MINUTE,
};

export type db = struct {
	opts: opts,
	keydir: *keydir,
	stale: *stale,
	df: *datafile,
};

export type error = !(...errors::error | fs::error | io::error);

export fn new(opts: opts) (*db | error) = {
	let kd = alloc([[]...]: keydir);
	let stale = alloc([[]...]: stale);

	let fids: []size = [];

	let ents = os::readdir(opts.dir)?;
	for (let i = 0z; i < len(ents); i += 1) {
		if (!strings::hassuffix(ents[i].name, ".bitcask.data")) {
			continue;
		};

		let filename = strings::trimprefix(ents[i].name, opts.dir);
		let (strfid, _) = strings::cut(filename, ".");
		let fid = strconv::stoz(strfid): size;

		append(fids, fid);
	};

	// must be sorted numerically
	sort::sort(fids, size(size), &cmp::sizes);

	let nextfid = 0z;
	for (let i = 0z; i < len(fids); i += 1) {
		let df = newdatafile(opts.dir, fids[i])?;

		match (os::open(strings::concat(opts.dir, "/", fmt::asprintf(HINTFILE, fids[i])), fs::flag::RDONLY)) {
		case let kdf: io::file =>
			keydir_decode(kd, kdf)?;
		case fs::error =>
			yield;
		};

		stale_set(stale, fids[i], df);
	};

	let nextfid = 1z;
	if (len(fids) > 0) {
		nextfid = fids[len(fids) - 1];
		let df = newdatafile(opts.dir, nextfid)?;

		if (df.off >= opts.maxfilesz) {
			nextfid += 1;
		};

		datafile_finish(df)?;
	};

	let df = newdatafile(opts.dir, nextfid)?;
	stale_del(stale, nextfid);
 
	return alloc(db {
		opts = opts,
		keydir = kd,
		stale = stale,
		df = df,
	});
};

export fn finish(db: *db) (void | error) = {
	match (os::create(strings::concat(db.opts.dir, "/", fmt::asprintf(HINTFILE, db.df.id)), fs::mode::USER_RWX, fs::flag::WRONLY)) {
	case let kdf: io::file =>
		keydir_encode(db.keydir, kdf)?;
	case fs::error =>
		yield;
	};

	keydir_finish(db.keydir);
	stale_finish(db.stale);
	datafile_finish(db.df)!;
};

@test fn new() void = {
	let dir = temp::dir();
	defer os::rmdirall(dir)!;

	let opts = defaultopts;
	opts.dir = dir;

	let db = new(opts)!;
	defer finish(db)!;
};

export fn put(db: *db, key: str, val: []u8) (void | error) = {
	let crc_ieee = crc32::crc32(&hash::crc32::ieee_table);
	hash::reset(&crc_ieee);
	hash::write(&crc_ieee, val);

	let now = time::now(time::clock::REALTIME);

	let hdr = header {
		cksum = crc32::sum32(&crc_ieee),
		ts = now,
		expiry = now,
		keysz = len(key),
		valsz = len(val),
	};

	let rec = record {
		hdr = hdr,
		key = key,
		val = val,
	};

	let recbuf: []u8 = alloc([0...], HDRSZ + rec.hdr.keysz+rec.hdr.valsz);
	record_encode(recbuf, &rec);

	let off = datafile_write(db.df, recbuf)?;

	let meta = alloc(meta {
		ts = rec.hdr.ts,
		recsz = HDRSZ + rec.hdr.keysz + rec.hdr.valsz,
		recpos = off,
		fid = db.df.id,
	});
	keydir_set(db.keydir, key, meta);

	return;
};

export fn get(db: *db, key: str) ([]u8 | void | error) = {
	let meta = match(keydir_get(db.keydir, key)) {
	case let m: *meta =>
		yield m;
	case void =>
		return void;
	};

	let reader = db.df;
	if (meta.fid != reader.id) {
		match(stale_get(db.stale, meta.fid)) {
		case let df: *datafile =>
			reader = df;
		case void =>
			return void;
		};
	};

	let rec: []u8 = alloc([0...], meta.recsz);
	datafile_readat(reader, meta.recpos, rec)?;

	let r = alloc(record { ... });
	record_decode(r, rec);

	return r.val;
};

export fn del(db: *db, key: str) (void | error) = {
	put(db, key, []: []u8)?;
	keydir_del(db.keydir, key);
};

export fn merge(db: *db) (void | error) = {
	return;
};
