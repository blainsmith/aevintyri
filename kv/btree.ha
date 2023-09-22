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
	return;
};

fn node_decode(n: *node, buf: []u8) void = {
	return;
};