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

// Options to configure when creating a new [[db]].
export type opts = struct {
	dir: str,
	maxfilesz: size,
};

// Convenient settings for some default [[opts]] values.
export let defaultopts = opts {
	dir = ".",
	maxfilesz = (1 << 32): size,
};

// This is the core database struct with all the options and file descriptors
// needed to perform [[put]], [[get]], [[del]], and [[merge]] operations.
//
// Users should use [[new]] with some [[defaultopts]] to initialize a new [[db]]
// struct to make it readdy for use.
export type db = struct {
	opts: opts,
	keydir: *keydir,
	stale: *stale,
	df: *datafile,
};

// Error indicating that the record is invalid because the checksum does not
// match.
export type invalid = !void;

// Error indicating the record has expired.
export type expired = !time::instant;

// Any error that might be an [[io::error]], [[fs::error]], or local error.
export type error = !(...errors::error | fs::error | io::error | invalid | expired);

// Converts a [[bitcask::error]] into a user-friendly string.
export fn strerror(err: error) str = {
	match (err) {
	case invalid =>
		return "Invalid record";
	case expired =>
		return "Expired record";
	case let err: fs::error =>
		return fs::strerror(err);
	case let err: io::error =>
		return io::strerror(err);
	case let err: errors::error =>
		return errors::strerror(err);
	};
};

fn unixnano(i: time::instant) i64 = {
	return (i.sec * 1e9) + i.nsec;
};

fn from_unixnano(s: i64, ns: i64) time::instant = {
	if (ns < 0 || ns >= 1e9) {
		let n = ns / 1e9;
		s += n;
		ns -= n * 1e9;
		if (ns < 0) {
			ns += 1e9;
			s -= 1;
		};
	};

	return time::instant {
		sec = s,
		nsec = ns,
	};
};

// Returns a new [[db]] with the provided options. Caller must use [[finish]]
// when done to free up and close any underlying memory and file handles.
export fn new(opts: opts) (*db | error) = {
	let kd = alloc([[]...]: keydir);
	let stale = alloc([[]...]: stale);

	let fids: []i64 = [];
	let ents = os::readdir(opts.dir)?;
	for (let i = 0z; i < len(ents); i += 1) {
		if (!strings::hassuffix(ents[i].name, ".bitcask.data")) {
			continue;
		};

		let filename = strings::trimprefix(ents[i].name, opts.dir);
		let (strfid, _) = strings::cut(filename, ".");
		let fid = strconv::stoi64(strfid): i64;

		append(fids, fid);
	};

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

	let fid = gendatafileid();
	let df = newdatafile(opts.dir, fid)?;

	return alloc(db {
		opts = opts,
		keydir = kd,
		stale = stale,
		df = df,
	});
};

// Frees and closes memory and file handles after encoding a hint file of the
// [[keydir]] to disk.
export fn finish(db: *db) (void | error) = {
	let kdf = os::create(strings::concat(db.opts.dir, "/", fmt::asprintf(HINTFILE, db.df.id)), fs::mode::USER_RWX, fs::flag::WRONLY)?;
	keydir_encode(db.keydir, kdf)?;

	keydir_finish(db.keydir);
	stale_finish(db.stale);
	datafile_finish(db.df)!;
};

// Return all keys in the database. Call must use [[strings::dupall]] to free
// the return value.
export fn keys(db: *db) ([]str | void) = {
	return keydir_keys(db.keydir);
};

// Puts a key/value into the [[db]].
export fn put(db :*db, key: str, val: []u8) (void | error) = {
	let crc_ieee = crc32::crc32(&hash::crc32::ieee_table);
	hash::reset(&crc_ieee);
	hash::write(&crc_ieee, val);

	let now = time::now(time::clock::REALTIME);

	let hdr = header {
		cksum = crc32::sum32(&crc_ieee),
		ts = now,
		expiry = time::instant { ... },
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

	rotate(db)?;
};

// Gets the value with the specified key from the [[db]].
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
	
	if (!record_valid(r)) {
		return invalid;
	};

	// if (record_expired(r)) {
	// 	return r.hdr.expiry: expired;
	// };

	return r.val;
};

// Deletes the value with the specified key from the [[db]].
export fn del(db: *db, key: str) (void | error) = {
	put(db, key, []: []u8)?;
	keydir_del(db.keydir, key);
	rotate(db)?;
};

fn rotate(db: *db) (void | error) = {
	// return early if the datafile size is not big enough
	if (!datafile_full(db.df, db.opts.maxfilesz)) {
		return;
	};

	let fid = gendatafileid();
	let df = newdatafile(db.opts.dir, fid)?;

	stale_set(db.stale, db.df.id, db.df);
	db.df = df;
};

// Merges all non-active data files down to a set of data files containing only
// recent keys and values since data files are append only. Over time data
// files will end up containing old and deleted values. Merge will remove and
// reclaim this disk space.
export fn merge(db: *db) (void | error) = {
	// rotate the files so that all current data is set as stale
	rotate(db)?;

	// get all of the keydir keys and stale datafile keys at this point
	let keydirkeys = keydir_keys(db.keydir): []str;
	let stalekeys = stale_keys(db.stale): []i64;

	// get all non-deleted and recent vals and put then into the newest
	// datafile from the rotation
	for (let i = 0z; i < len(keydirkeys); i += 1) {
		let val = match(get(db, keydirkeys[i])) {
		case let v: []u8 =>
			yield v;
		case void =>
			break;
		case error =>
			break;
		};
		put(db, keydirkeys[i], val)?;
	};

	// delete all stale datafiles from the cache and disk leaving only
	// the merged datafiles
	for (let i = 0z; i < len(stalekeys); i += 1) {
		stale_del(db.stale, stalekeys[i]);

		os::remove(strings::concat(db.opts.dir, "/", fmt::asprintf(DATAFILE, stalekeys[i])))?;
		os::remove(strings::concat(db.opts.dir, "/", fmt::asprintf(HINTFILE, stalekeys[i])))?;
	};
};

@test fn new() void = {
	let dir = temp::dir();
	defer os::rmdirall(dir)!;

	let opts = defaultopts;
	opts.dir = dir;

	let db = new(opts)!;
	defer finish(db)!;
};
