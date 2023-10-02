use io;
use os;
use temp;

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