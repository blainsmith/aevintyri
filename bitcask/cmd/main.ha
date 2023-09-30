use bitcask;
use log;
use strings;

export fn main() void = {
	let opts = bitcask::defaultopts;
	opts.maxfilesz = 300;

	let db = bitcask::new(opts)!;
	defer bitcask::finish(db)!;

	bitcask::put(db, "key1", ['h','e','l','l','l']: []u8)!;
	bitcask::put(db, "key2", ['h','e']: []u8)!;
	bitcask::put(db, "keykey4", ['h','e','l','l','l','l','p','!']: []u8)!;

	let val = bitcask::get(db, "key2")!: []u8;
	log::println(strings::fromutf8_unsafe(val));

	bitcask::rotate(db)!;

	bitcask::del(db, "key1")!;

	let val = bitcask::get(db, "key1")!: []u8;
	log::println(strings::fromutf8_unsafe(val));
};