use kv;
use log;

export fn main() void = {
	let dal = kv::newdal("./kv.db", kv::PAGESZ)!;

	let page = kv::dal_allocatepage(dal);
	page.num = kv::freelist_nextpage(dal.freelist);
	log::println("nextpage", page.num);
	page.data[0] = 'b';
	page.data[1] = 'l';
	page.data[2] = 'a';
	page.data[3] = 'i';
	page.data[4] = 'n';

	kv::dal_writepage(dal, page)!;
	kv::dal_writefreelist(dal, dal.freelist)!;

	kv::dal_close(dal)!;

	dal = kv::newdal("./kv.db", kv::PAGESZ)!;
	let page = kv::dal_allocatepage(dal);
	page.num = kv::freelist_nextpage(dal.freelist);
	log::println("nextpage", page.num);
	page.data[0] = 'l';
	page.data[1] = 'a';
	page.data[2] = 'u';
	page.data[3] = 'r';
	page.data[4] = 'i';
	page.data[5] = 'e';

	kv::dal_writepage(dal, page)!;

	let pagenum = kv::freelist_nextpage(dal.freelist);
	kv::freelist_releasepage(dal.freelist, pagenum);

	kv::dal_writefreelist(dal, dal.freelist)!;

	kv::dal_close(dal)!;
};
