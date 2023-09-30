use fmt;
use fs;
use io;
use log;
use os;
use strings;
use temp;
use time;

export type datafile = struct {
	w: io::handle,
	r: io::handle,
	id: i64,
	off: size,
};

fn gendatafileid() i64 = {
	return unixnano(time::now(time::clock::REALTIME));
};

export fn newdatafile(dir: str, idx: i64) (*datafile | io::error | fs::error) = {
	let path = strings::concat(dir, "/", fmt::asprintf(DATAFILE, idx));

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
	io::seek(df.r, pos: io::off, io::whence::SET)?;
	io::read(df.r, buf)?;

	return len(buf);
};

export fn datafile_write(df: *datafile, buf: []u8) (size | io::error) = {
	io::write(df.w, buf)?;

	let off = df.off;
	df.off += len(buf);

	return off;
};

export fn datafile_full(df: *datafile, limit: size) bool = {
	return (df.off >= limit);
};

export fn datafile_finish(df: *datafile) (void | io::error) = {
	io::close(df.w)?;
	io::close(df.r)?;
};

@test fn newdatafile() void = {
	let dir = temp::dir();
	defer os::rmdirall(dir)!;

	let df = newdatafile(dir, 1i64)!;
	assert(io::read(df.w, []: []u8) is io::error);
	assert(io::write(df.r, []: []u8) is io::error);
	assert(df.id == 1i64);
	assert(df.off == 0z);

	assert(io::write(df.w, [0, 1, 2]: []u8): size == 3);

	datafile_finish(df)!;

	let df2 = newdatafile(dir, 1)!;
	assert(df2.off == 3z);

	datafile_finish(df2)!;
};