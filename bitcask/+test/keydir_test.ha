use io;
use memio;
use time;

@test fn keydir_set_get_del() void = {
	let kd: keydir = [[]...];
	defer keydir_finish(&kd);

	keydir_set(&kd, "key1", &meta { fid = 1, ... });

	let m = keydir_get(&kd, "key1"): *meta;
	assert(m.fid == 1);

	keydir_del(&kd, "key1");

	let m2 = keydir_get(&kd, "key1");
	assert(m2 is void);
};

@test fn keydir_encode_decode() void = {
	// create an in-memory buffer to represent a file
	let kdf = memio::dynamic();

	// create a new keydir and fill it with some keys and meta
	let kd: keydir = [[]...];
	keydir_set(&kd, "key1", &meta {
		ts = time::now(time::clock::REALTIME),
		recsz = 3z,
		recpos = 10z,
		fid = 1i64,
	});
	keydir_set(&kd, "this is a longer key", &meta {
		ts = time::now(time::clock::REALTIME),
		recsz = 10z,
		recpos = 5z,
		fid = 10i64,
	});

	// encode the keydir to the in-memory file
	keydir_encode(&kd, &kdf: io::handle)!;

	// move the read cursor to the beginning of the file
	// to simulate opening a file of encoded keys/meta fresh
	// with data
	io::seek(&kdf, 0, io::whence::SET)!;

	// create another new keydir
	let kdnew: keydir = [[]...];

	// decode the in-memory file into the new keydir
	keydir_decode(&kdnew, &kdf: io::handle)!;

	// check the decoded keydir has the key we expected
	let m = keydir_get(&kdnew, "key1"): *meta;
	assert(m.recsz == 3z);
	assert(m.recpos == 10z);
	assert(m.fid == 1i64);
};