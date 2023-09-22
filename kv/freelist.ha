use endian;
use log;

export type freelist = struct {
	maxpage: size,
	releasedpages: []size,
};

export fn newfreelist() *freelist = {
	return alloc(freelist {
		maxpage = 0,
		releasedpages = alloc([], 0): []size,
	});
};

export fn freelist_finish(fl: *freelist) void = {
	free(fl.releasedpages);
	free(fl);
	return;
};

export fn freelist_releasepage(fl: *freelist, num: size) void = {
	append(fl.releasedpages, num);
};

export fn freelist_nextpage(fl: *freelist) size = {
	if (len(fl.releasedpages) != 0) {
		let num = fl.releasedpages[len(fl.releasedpages) - 1];
		fl.releasedpages = fl.releasedpages[..len(fl.releasedpages) - 1];
		return num;
	};
	fl.maxpage += 1;
	return fl.maxpage;
};

export fn freelist_encode(fl: *freelist, buf: []u8) void = {
	endian::beputu16(buf[0..2], fl.maxpage: u16);
	endian::beputu16(buf[2..4], len(fl.releasedpages): u16);

	let pos = 4;
	for (let i = 0z; i < len(fl.releasedpages); i += 1) {
		endian::beputu64(buf[pos..pos+8], fl.releasedpages[i]);
		pos += 8;
	};
	return;
};

export fn freelist_decode(fl: *freelist, buf: []u8) void = {
	fl.maxpage = endian::begetu16(buf[0..2]);
	fl.releasedpages = alloc([], endian::begetu16(buf[2..4])): []size;

	let pos = 4;
	for (let i = 0z; i < len(fl.releasedpages); i += 1) {
		fl.releasedpages[i] = endian::begetu64(buf[pos..pos+8]);
		pos += 8;
	};
};