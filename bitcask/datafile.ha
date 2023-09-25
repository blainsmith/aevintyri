use fmt;
use fs;
use io;
use os;

def DATAFILE: str = "bitcask_{}.db";

export type datafile = struct {
	w: io::handle,
	r: io::handle,
	id: size,
	off: size,
};

export fn newdatafile(dir: str, idx: size) (*datafile | io::error | fs::error) = {
	let path = fmt::asprintf(DATAFILE, idx);

	return match(os::stat(path)) {
	case let stat: fs::filestat =>
		yield alloc(datafile {
			w = os::open(path, fs::flag::WRONLY | fs::flag::APPEND)?,
			r = os::open(path, fs::flag::RDONLY)?,
			id = idx,
			off = stat.sz,
		});
	case fs::error =>
		yield alloc(datafile {
			w = os::create(path, fs::mode::USER_RWX, fs::flag::WRONLY | fs::flag::APPEND)?,
			r = os::open(path, fs::flag::RDONLY)?,
			id = idx,
			off = 0,
		});
	};
};