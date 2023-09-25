use endian;
use log;

export type metapage = struct {
	root: size,
	freelistpage: size,
};

export fn newmetapage() *metapage = {
	return alloc(metapage {
		root = 0,
		freelistpage = 0,
	});
};

export fn metapage_finish(mp: *metapage) void = {
	free(mp);
	return;
};

export fn metapage_encode(mp: *metapage, buf: []u8) void = {
	endian::leputu64(buf[0..8], mp.root: u64);
	endian::leputu64(buf[8..16], mp.freelistpage: u64);
	return;
};

export fn metapage_decode(mp: *metapage, buf: []u8) void = {
	let r = endian::legetu64(buf[0..8]): size;
	let flp = endian::legetu64(buf[8..16]): size;
	mp.root = r;
	mp.freelistpage = flp;
};