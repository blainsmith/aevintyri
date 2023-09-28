use bitcask;
use log;
use strings;

export fn main() void = {
	let db = bitcask::newdb(bitcask::defaultopts)!;
	defer bitcask::db_finish(db)!;

	bitcask::db_put(db, "key1", ['h','e','l','l','l']: []u8)!;
	bitcask::db_put(db, "key2", ['h','e']: []u8)!;
	bitcask::db_put(db, "keykey4", ['h','e','l','l','l','l','p','!']: []u8)!;

	let val = bitcask::db_get(db, "key2")!: []u8;
	log::println(strings::fromutf8_unsafe(val));
};