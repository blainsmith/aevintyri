use ascii;
use bitcask;
use bufio;
use getopt;
use io;
use log;
use os;
use strings;

def PROMPT: str  = "\nbitcask> ";

export fn main() void = {
	let opts = bitcask::defaultopts;

	const cmd = getopt::parse(os::args,
		"Bitcask Client",
		('d', "dir", "directory where Bitcask data files are stored"),
	);
	defer getopt::finish(&cmd);

	for (let i = 0z; i < len(cmd.opts); i += 1) {
		const opt = cmd.opts[i];
		switch (opt.0) {
		case 'd' =>
			opts.dir = opt.1;
		case => abort(); // unreachable
		};
	};

	let db = bitcask::new(opts)!;
	defer bitcask::finish(db)!;

	let scn = bufio::newscanner(os::stdin, 1024);
	defer bufio::finish(&scn);

	for (true) {
		io::write(os::stderr, strings::toutf8(PROMPT))!;

		let line = bufio::scan_line(&scn)!: const str;
		let (c, args) = strings::cut(line, " ");
		switch (ascii::strupper(c)) {
		case "GET" =>
			let (key, _) = strings::cut(args, " ");
			match (bitcask::get(db, key)!) {
			case let val: []u8 =>
				io::write(os::stderr, val)!;
			case void =>
				io::write(os::stderr, strings::toutf8("Key not found"))!;
			};
		case "PUT" =>
			let (key, val) = strings::cut(args, " ");
			bitcask::put(db, key, strings::toutf8(val))!;
			io::write(os::stderr, strings::toutf8("+OK"))!;
		case "DEL" =>
			let (key, _) = strings::cut(args, " ");
			bitcask::del(db, key)!;
			io::write(os::stderr, strings::toutf8("+OK"))!;
		case "MERGE" =>
			bitcask::merge(db)!;
			io::write(os::stderr, strings::toutf8("+OK"))!;
		case "QUIT" =>
			break;
		case =>
			yield;
		};
	};
};