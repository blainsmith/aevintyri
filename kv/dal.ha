use errors;
use fs;
use io;
use log;
use os;

export def PAGESZ: size = 4096;

export type error = !(...errors::error | fs::error | io::error);

export type page = struct {
	num: size,
	data: []u8,
};

export type dal = struct {
	file: io::handle,
	pagesz: size,
	metapage: *metapage,
	freelist: *freelist,
};

export fn newdal(path: str, pagesz: size) (*dal | error) = {
	match(os::stat(path)) {
	case fs::filestat =>
		let mp = newmetapage();
		let fl = newfreelist();
		let f = os::open(path, fs::flag::RDWR)?;
		let d = alloc(dal {
			file = f,
			pagesz = pagesz,
			metapage = mp,
			freelist = fl,
		});

		d.metapage = dal_readmetapage(d)?;
		d.freelist = dal_readfreelist(d)?;

		return d;
	case fs::error =>
		let mp = newmetapage();
		let fl = newfreelist();

		let d = alloc(dal {
			file = os::create(path, fs::mode::USER_RWX, fs::flag::RDWR)?,
			pagesz = pagesz,
			metapage = mp,
			freelist = fl,
		});

		d.metapage.freelistpage = freelist_nextpage(fl);
		dal_writefreelist(d, fl)?;
		dal_writemetapage(d, mp)?;

		return d;
	};
};

export fn dal_close(d: *dal) (void | error) = {
	return io::close(d.file)?;
};

@test fn newdal() void = {
	assert(1 == 1);
};

export fn dal_allocatepage(d: *dal) *page = {
	return alloc(page {
		num = 0,
		data = alloc([0...], d.pagesz),
	});
};

export fn dal_readpage(d: *dal, num: size) (*page | error) = {
	let p = dal_allocatepage(d);

	let off = (num * d.pagesz): i64;
	io::seek(d.file, off, io::whence::SET)?;

	match (io::read(d.file, p.data)?) {
	case size =>
		return p;
	case io::EOF =>
		return p;
	};
};

export fn dal_readmetapage(d: *dal) (*metapage | error) = {
	let p = dal_readpage(d, 0)?;

	let mp = alloc(metapage {
		freelistpage = 0,
	});

	metapage_decode(mp, p.data);

	return mp;
};

export fn dal_readfreelist(d: *dal) (*freelist | error) = {
	let p = dal_readpage(d, d.metapage.freelistpage)?;

	let fl = alloc(freelist {
		maxpage = 0,
		releasedpages = alloc([], 0): []size,
	});

	freelist_decode(fl, p.data);

	return fl;
};

export fn dal_readnode(d: *dal, num: size) (*node | error) = {
	let p = dal_readpage(d, num)?;

	let n = newnode();
	node_decode(n, p.data);
	n.pagenum = num;

	return n;
};

export fn dal_writepage(d: *dal, p: *page) (void | error) = {
	let off = (p.num * d.pagesz): i64;
	io::seek(d.file, off, io::whence::SET)?;

	io::write(d.file, p.data)?;

	return;
};

export fn dal_writemetapage(d: *dal, mp: *metapage) (*page | error) = {
	let p = dal_allocatepage(d);
	p.num = 0;

	metapage_encode(mp, p.data);

	dal_writepage(d, p)?;

	return p;
};

export fn dal_writefreelist(d: *dal, fl: *freelist) (*page | error) = {
	let p = dal_allocatepage(d);
	p.num = d.metapage.freelistpage;

	freelist_encode(fl, p.data);

	dal_writepage(d, p)?;
	d.metapage.freelistpage = p.num;

	return p;
};

export fn dal_writenode(d: *dal, n: *node) (*node | error) = {
	let p = dal_allocatepage(d);
	if (n.pagenum == 0) {
		p.num = freelist_nextpage(d.freelist);
		n.pagenum = p.num;
	} else {
		p.num = n.pagenum;
	};

	node_encode(n, p.data);

	dal_writepage(d, p)?;

	return n;
};