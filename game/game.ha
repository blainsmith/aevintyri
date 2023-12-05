use errors;
use fmt;
use io;
use log;
use os;
use strings;

use vendor::format::scfg;

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
	welcome: str,
	currarea: *area,
	inventory: [](str, str, str, str, str),
	allareas: []*area,
};

export type area = struct {
	id: str,
	name: str,
	dialog: str,

	adjacent: [](direction, *area),
	subarea: (str, str),
	//(Item Name, Item Description, Where to use, What it does, Has it been used)
	item: (str, str, str, str, str),
};

export fn parse(f: io::handle) (*map | scfg::error | error) = {
	let scn = scfg::scan(f);
	defer scfg::finish(&scn);

	let a = -1;
	let areas: []*area = alloc([], 0);
	let dirs: [](str, direction, dirtype, str) = [];
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
		//probably want a helper here eventually, since I'd like to have some non string params like a used bool
			areas[a].item = (strings::dup(directive.2[0]), strings::dup(directive.2[1]), strings::dup(directive.2[2]), strings::dup(directive.2[3]), strings::dup(directive.2[4]));
		case "north", "south", "east", "west" =>
			let dir = match (parsedirection(directive.1)) {
			case let i: invalid =>
				return i;
			case let d: direction =>
				yield d;
			};

			let dirtype = match (parsedirtype(directive.2[0])) {
			case let i: invalid =>
				return i;
			case let d: dirtype =>
				yield d;
			};

			append(dirs, (areas[a].name, dir, dirtype, directive.2[1]));
		case =>
			yield;
		};
	};

	for (let d = 0z; d < len(dirs); d += 1) {
		let a1 = getarea(areas, dirs[d].0) as *area;
		let a2 = getarea(areas, dirs[d].3) as *area;
		if (dirs[d].2 == dirtype::BIDIRECTIONAL) {
			bidirectional(a1, dirs[d].1, a2);
		} else {
			unidirectional(a1, dirs[d].1, a2);
		};
		
	};
	return alloc(map {
		welcome = strings::dup(welcome),
		currarea = areas[0],
		allareas = areas,
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
	assert(map.currarea.name == "Wooded Forest");
	assert(map.currarea.adjacent[0].1.name == "Street Light");
	assert(map.currarea.adjacent[0].1.adjacent[1].1.name == "Shipping Container");
	assert(map.currarea.adjacent[0].1.adjacent[2].1.name == "Car Accident");
};

export fn map_dup(m: *map) *map = {
	return alloc(map {
		currarea = alloc(*m.currarea),
		allareas = m.allareas,
		...
	});
};

export fn map_loadarea(m: *map, aid: str) void = {
	for (let i = 0z; i < len(m.allareas); i += 1) {
		if (m.allareas[i].id == aid) {
			m.currarea = m.allareas[i];
		};
	};

	return;
};

export fn move(m: *map, d: direction) bool = {
	for (let i = 0z; i < len(m.currarea.adjacent); i += 1) {
		if (m.currarea.adjacent[i].0 == d) {
			m.currarea = m.currarea.adjacent[i].1;
			return true;
		};
	};

	return false;
};

export fn look(m: *map, a: str) (str | void) = {
	if (m.currarea.subarea.0 == a) {
		return m.currarea.subarea.1;
	};
	return;
};

export fn pick(m: *map, i: str) (str | void) = {
	if (m.currarea.item.0 == i) {
		append(m.inventory, m.currarea.item);
		return m.currarea.item.1;
	};
	return;
};

export fn use_item(map: *map, args: str) str = {
	//loop over all items in inventory
	for (let i = 0z; i < len(map.inventory); i += 1) {
		if (map.inventory[i].0 == args) {//using an item we have, now check if in correct location
			if (map.inventory[i].2 == map.currarea.name) { //in correct location, if unused do action
				if (map.inventory[i].4 == "false") { //unused now do action
					//item layout for reference[name, description, location of use, action:details, used boolean]
					let (act, details) = strings::cut(map.inventory[i].3, ":");
					switch (act) {
					case "connect" => 
					//if action is connect then details should be the location being connected. currently always connects current location to what is in details
						let (loc, direc) = strings::cut(details, ",");
						let dir = trustedparsedirection(direc);
						let a2 = match (getarea(map.allareas, loc)) {
						case let i: void =>
							return "Something is broken, area in script not in map";
						case let a: *area =>
							yield a;
						};
						unidirectional(map.currarea, dir, a2);
					case => return "other actions";
					};

					map.inventory[i].4 = "true";
					return strings::concat("You used the ", args);
				} else {
					return "You have already used this item";
				};
			} else {
				return "It seems like this needs to be used somewhere else";
			};
		};
	};
	return "You don't have an item like that";
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

export fn bidirectional(a: *area, d: direction, b: *area) void = {
	append(a.adjacent, (d, b));
	switch (d) {
	case direction::NORTH => append(b.adjacent, (direction::SOUTH, a));
	case direction::SOUTH => append(b.adjacent, (direction::NORTH, a));
	case direction::EAST => append(b.adjacent, (direction::WEST, a));
	case direction::WEST => append(b.adjacent, (direction::EAST, a));
	};
};

export fn unidirectional(a: *area, d: direction, b: *area) void = {
	append(a.adjacent, (d, b));
};

export fn areaequals(map1: *map, map2: *map) bool = {
	return (map1.currarea.name == map2.currarea.name);
};

export fn printslice(areas: []*area) void = {
	fmt::println("--start--")!;
	for (let a = 0z; a < len(areas); a += 1) {
		fmt::println(areas[a].name)!;
	};
	fmt::println("--end--")!;
};

@test fn move() void = {
	let forest = area { name = "Wooded Forest", dialog = "You find yourself alone in a wooded forest. To the EAST you see a dim light.", ... };
	let streetlight = area { name = "Street Light", dialog = "After walking through the forest you come to a clearing and come upon a street light at the end of the clearing. The road runs EAST to WEST and has no cars in sight.", ... };

	bidirectional(&forest, direction::EAST, &streetlight);

	let m = map { currarea = &forest, ... };
	assert(m.currarea.name == "Wooded Forest");

	move(&m, direction::EAST);
	assert(m.currarea.name == "Street Light");
};

