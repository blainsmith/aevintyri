use errors;
use fs;
use io;
use os;
use strconv;
use strings;
use time;

def HINTSFILE: str = "bitcask.hints";

export type opts = struct {
	dir: str,
	maxfilesz: size,
	sync: time::duration,
	compaction: time::duration,
	sizecheck: time::duration,
};

let defaultopts = opts {
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
		let (_, num) = strings::cut(filename, "_");
		let fidx = strconv::stoz(num): size;

		let df = newdatafile(opts.dir, fidx)?;
		stale_set(stale, fidx, df);

		idx = fidx;
	};

	let df = newdatafile(opts.dir, idx+1)?;
 
	let kd = alloc([[]...]: keydir);
	match (os::open(strings::concat(opts.dir, HINTSFILE), fs::flag::RDONLY)) {
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

export fn db_finish(db: *db) void = {
	keydir_finish(db.keydir);
	stale_finish(db.stale);
	datafile_finish(db.df)!;
};

@test fn newdb() void = {
	let db = newdb(defaultopts)!;
};