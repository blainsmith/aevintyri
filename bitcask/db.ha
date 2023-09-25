use errors;
use fs;
use os;
use time;

export type opts = struct {
	dir: str,
	maxfilesz: size,
	sync: time::duration,
	compaction: time::duration,
	sizecheck: time::duration,
};

let defaultops = opts {
	dir = ".",
	maxfilesz = (1 << 32): size,
	sync = time::MINUTE,
	compaction = 6 * time::HOUR,
	sizecheck = time::MINUTE,
};

export type db = struct {
	opts: opts,
	keydir: *keydir,
	df: *datafile,
};

export type error = !(...errors::error | fs::error);

export fn newdb(opts: *opts) (*db | error) = {
	let ents = os::readdir(opts.dir)?;
	return errors::invalid;
};
