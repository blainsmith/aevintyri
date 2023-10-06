use ascii;
use bitcask;
use bufio;
use getopt;
use fmt;
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

	let scn = bufio::newscanner(os::stdin, 1024);

	for (true) {
		fmt::print(PROMPT)!;

		let line = bufio::scan_line(&scn)!: const str;
		let (c, args) = strings::cut(line, " ");
		switch (ascii::strupper(c)) {
		case "KEYS" =>
			match (bitcask::keys(db)) {
			case let keys: []str =>
				for (let i = 0z; i < len(keys); i += 1) {
					fmt::printfln("{}) {}", i, keys[i])!;
				};
				strings::freeall(keys);
			case void =>
				fmt::println("(empty array)")!;
			};
		case "GET" =>
			let (key, _) = strings::cut(args, " ");
			key = strings::dup(key);
			match (bitcask::get(db, key)) {
			case let val: []u8 =>
				fmt::println(strings::fromutf8_unsafe(val))!;
			case void =>
				fmt::println("Key not found")!;
			case let err: bitcask::error =>
				fmt::println(bitcask::strerror(err))!;
			};
		case "PUT" =>
			let (key, val) = strings::cut(args, " ");
			match (bitcask::put(db, key, strings::toutf8(val))) {
			case void =>
				fmt::println("+OK")!;
			case let err: bitcask::error =>
				fmt::println(bitcask::strerror(err))!;
			};
		case "DEL" =>
			let (key, _) = strings::cut(args, " ");
			match (bitcask::del(db, key)) {
			case void =>
				fmt::println("+OK")!;
			case let err: bitcask::error =>
				fmt::println(bitcask::strerror(err))!;
			};
		case "MERGE" =>
			match (bitcask::merge(db)) {
			case void =>
				fmt::println("+OK")!;
			case let err: bitcask::error =>
				fmt::println(bitcask::strerror(err))!;
			};
		case "QUIT" =>
			// bufio::finish(&scn);
			bitcask::finish(db)!;
			return;
		case =>
			fmt::println("Unknown command")!;
			yield;
		};
	};

	// bufio::finish(&scn);
	// bitcask::finish(db)!;
};