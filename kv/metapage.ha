use endian;
use log;

export type metapage = struct {
	freelistpage: size,
};

export fn newmetapage() *metapage = {
	return alloc(metapage {
		freelistpage = 0,
	});
};

export fn metapage_finish(mp: *metapage) void = {
	free(mp);
	return;
};

export fn metapage_encode(mp: *metapage, buf: []u8) void = {
	endian::leputu64(buf[0..8], mp.freelistpage: u64);
	return;
};

export fn metapage_decode(mp: *metapage, buf: []u8) void = {
	let flp = endian::legetu64(buf[0..8]): size;
	log::println("decoded freepagelist", flp);
	mp.freelistpage = flp;
};