use os;
use temp;

@test fn new() void = {
	let dir = temp::dir();
	defer os::rmdirall(dir)!;

	let opts = defaultopts;
	opts.dir = dir;

	let db = new(opts)!;
	defer finish(db)!;
};

