use bitcask;
use log;
use strings;
use time;

export fn main() void = {
	let opts = bitcask::defaultopts;

	// set the max file size to 1 byte to force a datafile rotation after
	// every put/del operation to create multiple .data and .hint files
	opts.maxfilesz = 1;

	let db = bitcask::new(opts)!;
	defer bitcask::finish(db)!;

	// put and del some data and also overwrite key2 with updated data
	bitcask::put(db, "key1", ['h','e','l','l','l']: []u8)!;
	bitcask::put(db, "key2", ['h','e']: []u8)!;
	bitcask::put(db, "keykey4", ['h','e','l','l','l','l','p','!']: []u8)!;
	bitcask::del(db, "key1")!;
	bitcask::put(db, "key2", ['g','a','t','e','c','h'])!;

	// merge the datafiles to remove deleted keys from .data files
	bitcask::merge(db)!;

	// key2 should still exist, but hold the newest value
	match (bitcask::get(db, "key2")!) {
	case let val: []u8 =>
		log::println(strings::fromutf8_unsafe(val));
	case void =>
		log::println("key2 does not exist?!");
	};

	// key1 should be deleted and not exist in any .data and .hint file
	match(bitcask::get(db, "key1")!) {
	case []u8 =>
		log::println("key1 exists?!");
	case void =>
		log::println("key one deleted");
	};
};