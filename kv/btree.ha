use endian;

export type item = struct {
	key: []u8,
	val: []u8,
};

export type node = struct {
	pagenum: size,
	items: []*item,
	children: []size,
};

export fn newnode() *node = {
	return alloc(node { ... });
};

export fn node_finish(n: *node) void = {
	free(n.items);
	free(n.children);
	free(n);
};

export fn newitem(k: []u8, v: []u8) *item = {
	return alloc(item {
		key = k,
		val = v,
	});
};

export fn item_finish(i: *item) void = {
	free(i.key);
	free(i.val);
	free(i);
};

fn node_isleaf(n: *node) bool = {
	return len(n.children) == 0;
};

fn node_encode(n: *node, buf: []u8) void = {
	let leftpos = 1;
	let rightpos = len(buf) - 1;

	let isleaf = node_isleaf(n);

	buf[leftpos] = 0;
	if (isleaf) {
		buf[leftpos] = 1;
	};
	leftpos += 1;

	endian::leputu16(buf[leftpos..leftpos+2], len(n.items): u16);
	leftpos += 2;

	for (let i = 0z; i < len(n.items); i += 1) {
		let item = n.items[i];
		if (!isleaf) {
			let child = n.children[i];
			endian::leputu64(buf[leftpos..leftpos+8], child: u64);
			leftpos += 8;
		};

		let klen = len(item.key);
		let vlen = len(item.val);

		let off = rightpos - klen - vlen - 2;
		endian::leputu16(buf[leftpos..leftpos+2], off: u16);
		leftpos += 2;

		rightpos -= vlen;
		buf[rightpos..rightpos+vlen] = item.val;

		rightpos -= 1;
		buf[rightpos] = vlen: u8;

		rightpos -= klen;
		buf[rightpos..rightpos+klen] = item.key;

		rightpos -= 1;
		buf[rightpos] = klen: u8;
	};

	if (!isleaf) {
		let lastchild = n.children[len(n.children) - 1];
		endian::leputu64(buf[leftpos..leftpos+8], lastchild: u64);
	};

	return;
};

fn node_decode(n: *node, buf: []u8) void = {
	let leftpos = 0;

	let isleaf = buf[leftpos];
	leftpos += 1;

	let numitems = endian::legetu16(buf[leftpos..leftpos+2]);
	leftpos += 2;

	for (let i = 0z; i < numitems: size; i += 1) {
		if (isleaf == 0) {
			let num = endian::legetu64(buf[leftpos..leftpos+8]);
			leftpos += 8;

			append(n.children, num: size);
		};

		let off = endian::legetu16(buf[leftpos..leftpos+2]);
		leftpos += 2;

		let klen = buf[off];
		off += 1;

		let key = buf[off..off+klen];
		off += klen;

		let vlen = buf[off];
		off += 1;

		let val = buf[off..off+vlen];
		off += vlen;

		let item = newitem(key, val);
		append(n.items, item);
	};

	if (isleaf == 0) {
		let num = endian::legetu64(buf[leftpos..leftpos+8]);
		append(n.children, num: size);
	};

	return;
};