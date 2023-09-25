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

export fn datafile_readat(df: *datafile, pos: size, buf: []u8) (size | io::error) = {
	let start = pos - len(buf);
	let rec: []u8 = alloc([], start);

	io::seek(df.r, start: io::off, io::whence::SET)?;
	io::read(df.r, rec)?;

	return len(buf);
};

export fn datafile_write(df: *datafile, buf: []u8) (size | io::error) = {
	io::write(df.w, buf)?;

	let off = df.off;
	df.off += len(buf);

	return off;
};

export fn datafile_close(df: *datafile) (void | io::error) = {
	io::close(df.w)?;
	io::close(df.r)?;
};