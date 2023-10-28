use log;

export const WELCOME: str = "+----------------------+\n| Welcome to Ævintýri! |\n+----------------------+";

export const ABOUT: str = `Ævintýri

Developed by:
  Blain
  Jack
  Avery

Built with:
  https://harelang.org

Open source libraries:
  https://git.sr.ht/~sircmpwn/hare-ev
  https://git.sr.ht/~sircmpwn/hare-json
  https://git.sr.ht/~chrisppy/hare-scfg
  https://git.sr.ht/~blainsmith/hare-bitcask
  https://git.sr.ht/~blainsmith/hare-logfmt`;

export const PROMPT: str = "\n\n» ";

export type map = struct {
	id: str,
	allareas: []*area,
	currarea: *area,
	inventory: []str,
};

export type area = struct {
	id: str,
	name: str,
	dialog: str,

	adjacent: [](direction, *area),
	subarea: (str, str),
	item: (str, str),
};

export fn newmap() *map = {
	let forest = alloc(area { id = "wf", name = "Wooded Forest", dialog = "You find yourself alone in a wooded forest. To the EAST you see a dim light.", ... });
	let streetlight = alloc(area { id = "sl", name = "Street Light", dialog = "You come to a clearing and come upon a street light at the end of the clearing. The road runs NORTH to SOUTH and has no cars in sight.", ... });
	let container = alloc(area {
		id = "c",
		name = "Shipping Container",
		dialog = "You make your way up the street and stop next to a rusted out shipping container. The door is open.",
		subarea = ("container floor", "The floor is covered in blood and a human hand holding an old iron key."),
		item = ("old iron key", "You pick up the bloody key and place it into you pocket."),
		...
	});

	adjacent(forest, direction::EAST, streetlight);
	adjacent(streetlight, direction::NORTH, container);

	let m = alloc(map {
		id = "zombie.script",
		allareas = alloc([forest, streetlight, container]),
		currarea = forest,
		...
	});

	return m;
};

export fn loadmap(mid: str, aid: str) *map = {
	let m = newmap();
	for (let i = 0z; i < len(m.allareas); i += 1) {
		if (m.allareas[i].id == aid) {
			m.currarea = m.allareas[i];
		};
	};
	return m;
};

export fn move(m: *map, d: direction) void = {
	for (let i = 0z; i < len(m.currarea.adjacent); i += 1) {
		if (m.currarea.adjacent[i].0 == d) {
			m.currarea = m.currarea.adjacent[i].1;
		};
	};

	return;
};

export fn look(m: *map, a: str) (str | void) = {
	if (m.currarea.subarea.0 == a) {
		return m.currarea.subarea.1;
	};
	return;
};

export fn pick(m: *map, i: str) (str | void) = {
	if (m.currarea.item.0 == i) {
		append(m.inventory, m.currarea.item.1);
		return m.currarea.item.1;
	};
	return;
};

export fn help() str = {
	return `nick <name> - identify yourself as <name>
load - loads your previously saved area
move <direction> - move in the given direction
look <object> - look at specific object to inspect it
pick <item> - pick up an item
use <item> - use an item
quit - quit the game and disconnect
help - prints this help text
about - show information about the game`;
};

export fn adjacent(a: *area, d: direction, b: *area) void = {
	append(a.adjacent, (d, b));
	switch (d) {
	case direction::NORTH => append(b.adjacent, (direction::SOUTH, a));
	case direction::SOUTH => append(b.adjacent, (direction::NORTH, a));
	case direction::EAST => append(b.adjacent, (direction::WEST, a));
	case direction::WEST => append(b.adjacent, (direction::EAST, a));
	};
};

@test fn move() void = {
	let forest = area { name = "Wooded Forest", dialog = "You find yourself alone in a wooded forest. To the EAST you see a dim light.", ... };
	let streetlight = area { name = "Street Light", dialog = "After walking through the forest you come to a clearing and come upon a street light at the end of the clearing. The road runs EAST to WEST and has no cars in sight.", ... };

	adjacent(&forest, direction::EAST, &streetlight);

	let m = map { currarea = &forest, ... };
	assert(m.currarea.name == "Wooded Forest");

	move(&m, direction::EAST);
	assert(m.currarea.name == "Street Light");
};