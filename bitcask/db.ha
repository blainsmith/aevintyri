use errors;
use fs;
use hash;
use hash::crc32;
use io;
use log;
use os;
use strconv;
use strings;
use temp;
use time;

def HINTSFILE: str = "bitcask.hints";

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

export fn newdb(opts: opts) (*db | error) = {
	let idx = 0z;

	let stale = alloc([[]...]: stale);

	let ents = os::readdir(opts.dir)?;
	for (let i = 0z; i < len(ents); i += 1) {
		if (!strings::hassuffix(ents[i].name, ".db")) {
			continue;
		};

		let filename = strings::trimprefix(ents[i].name, opts.dir);
		let (num, _) = strings::cut(strings::cut(filename, "_").1, ".");
		let fidx = strconv::stoz(num): size;

		let df = newdatafile(opts.dir, fidx)?;
		stale_set(stale, fidx, df);

		idx = fidx;
	};

	let df = newdatafile(opts.dir, idx+1)?;
 
	let kd = alloc([[]...]: keydir);
	match (os::open(strings::concat(opts.dir, "/", HINTSFILE), fs::flag::RDONLY)) {
	case let kdf: io::file =>
		keydir_decode(kd, kdf)?;
	case fs::error =>
		yield;
	};

	return alloc(db {
		opts = opts,
		keydir = kd,
		stale = stale,
		df = df,
	});
};

export fn db_finish(db: *db) (void | error) = {
	match (os::create(strings::concat(db.opts.dir, "/", HINTSFILE), fs::mode::USER_RWX, fs::flag::WRONLY)) {
	case let kdf: io::file =>
		keydir_encode(db.keydir, kdf)?;
	case fs::error =>
		yield;
	};

	keydir_finish(db.keydir);
	stale_finish(db.stale);
	datafile_finish(db.df)!;
};

@test fn newdb() void = {
	let dir = temp::dir();
	defer os::rmdirall(dir)!;

	let opts = defaultopts;
	opts.dir = dir;

	let db = newdb(opts)!;
	defer db_finish(db)!;
};

export fn db_put(db: *db, key: str, val: []u8) (void | error) = {
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

export fn db_get(db: *db, key: str) ([]u8 | void | error) = {
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

export fn db_del(db: *db, key: str) (void | error) = {
	return;
};

export type iterator = struct {
	key: str,
	val: []u8,
};

export fn db_iter(db: *db) *iterator = {
	return alloc(iterator { ... });
};

export fn db_next(iter: *iterator) ((str, []u8) | void) = {
	return;
};

export fn db_prev(iter: *iterator) ((str, []u8) | void) = {
	return;
};