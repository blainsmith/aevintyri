use errors;
use fmt;
use io;
use log;
use os;
use strings;

use vendor::format::scfg;

const ABOUT: str = `Ævintýri

Developed by:
  Blain
  Jack
  Avery

Built with:
  https://harelang.org

Open source libraries:
  https://git.sr.ht/~sircmpwn/hare-ev
  https://git.sr.ht/~chrisppy/hare-scfg
  https://git.sr.ht/~blainsmith/hare-logfmt`;

export const PROMPT: str = "\n\n» ";

export type map = struct {
	welcome: str,
	currarea: *area,
	inventory: []str,
};

export type area = struct {
	name: str,
	dialog: str,

	adjacent: [](direction, *area),
	subarea: (str, str),
	item: (str, str),
};

export fn parse(f: io::handle) (*map | scfg::error | error) = {
	let scn = scfg::scan(f);
	defer scfg::finish(&scn);

	let a = -1;
	let areas: []*area = [];
	let dirs: [](str, direction, str) = [];
	let welcome = "";

	for (true) {
		let directive = match (scfg::next(&scn)?) {
		case io::EOF =>
			break;
		case let d: scfg::directive =>
			yield d;
		};

		switch (directive.1) {
		case "welcome" =>
			welcome = directive.2[0];
		case "area" =>
			a += 1;
			let area = alloc(area {
				name = strings::dup(directive.2[0]),
				...
			});
			append(areas, area);
		case "dialog" =>
			areas[a].dialog = strings::dup(directive.2[0]);
		case "subarea" =>
			areas[a].subarea = (strings::dup(directive.2[0]), strings::dup(directive.2[1]));
		case "item" =>
			areas[a].item = (strings::dup(directive.2[0]), strings::dup(directive.2[1]));
		case "north", "south", "east", "west" =>
			let dir = match (parsedirection(directive.1)) {
			case let i: invalid =>
				return i;
			case let d: direction =>
				yield d;
			};

			append(dirs, (areas[a].name, dir, directive.2[0]));
		case =>
			yield;
		};
	};

	for (let d = 0z; d < len(dirs); d += 1) {
		let a1 = getarea(areas, dirs[d].0) as *area;
		let a2 = getarea(areas, dirs[d].2) as *area;

		adjacent(a1, dirs[d].1, a2);
	};

	return alloc(map {
		welcome = strings::dup(strings::concat(welcome, "\n\n")),
		currarea = areas[0],
		...
	});
};

fn getarea(areas: []*area, name: str) (*area | void) = {
	for (let a = 0z; a < len(areas); a += 1) {
		if (areas[a].name == name) {
			return areas[a];
		};
	};
	return;
};

@test fn parse() void = {
	let script = os::open("./scripts/zombie.script")!;
	let map = parse(script)!;
	assert(map.welcome == "TBD");
	assert(map.currarea.name == "Wooded Forest");
	assert(map.currarea.adjacent[0].1.name == "Street Light");
	assert(map.currarea.adjacent[0].1.adjacent[1].1.name == "Shipping Container");
	assert(map.currarea.adjacent[0].1.adjacent[2].1.name == "Car Accident");
};

export fn map_dup(m: *map) *map = {
	return alloc(map {
		welcome = strings::dup(m.welcome),
		currarea = alloc(*m.currarea),
		...
	});
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
	return "move <direction>\nlook <direction>\npick <item-name>\nuse <item-name>\nsay <what-to-say> (talk to others in same area)\nquit\nhelp\nabout";
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

export fn areaequals(map1: *map, map2: *map) bool = {
	return (map1.currarea.name == map2.currarea.name);
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