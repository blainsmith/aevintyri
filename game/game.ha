use errors;
use fmt;
use io;
use bufio;
use log;

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

	adjacent: [](direction, str), // i changed the *area to str and instead of directly holding the *area we instead search the map key-dir for the str key that contains the *area
	subarea: (str, str),
	item: (str, str),
};

export fn parse(f: io::handle) (*map | scfg::error) = {
	let scn = scfg::scan(f);
	defer scfg::finish(&scn); 
	let kd = alloc([[]...]: keydir);
	let first = true;
	let newarea: *area;

	for (true) {
		let directive = match (scfg::next(&scn)?) {
		case io::EOF =>
			break;
		case let d: scfg::directive =>
			yield d;
		};

		// fmt::printfln("directive ({}, {})", directive.0, directive.1)!;
		if (len(directive.0) == 0) { // if the block param is empty then it marks a new area
			if (!first) {
				keydir::keydir_set(kd, *newarea.name, &newarea);
			}
			newarea = alloc(1);
			*newarea.name = directive.1;
			if (first) {
				first = false;
			}
		}
		switch (directive.1) {
		case "dialog":
			*newarea.dialog = directive.2[1];
			break;
		case "north":
			adjacent(newarea, direction::NORTH, directive.2[1]);
			break;
		case "south":
			adjacent(newarea, direction::SOUTH, directive.2[1]);
			break;
		case "east":
			adjacent(newarea, direction::EAST, directive.2[1]);
			break;
		case "west":
			adjacent(newarea, direction::WEST, directive.2[1]);
			break;
		case "subarea":
			let subname: str = directive.2[1];
			directive = scfg::next(&scn);
			*newarea.subarea = (subname, directive.2[1]);
			break;
		case "item":
			let itemname: str = directive.2[1];
			directive = scfg::next(&scn);
			*newarea.item = (itemname, directive.2[1]);
			break;
		};
	};
	// Should return some "map" that was built from the loop above.
	// need a method for searching for assembling adjacency lists of each area
	// if I store the areas in a hashmap then find the adjacent areas is easy just use the name as the key
	return newmap();
};


export fn newmap() *map = {
	let forest = alloc(area { name = "Wooded Forest", dialog = "You find yourself alone in a wooded forest. To the EAST you see a dim light.", ... });
	let streetlight = alloc(area { name = "Street Light", dialog = "You come to a clearing and come upon a street light at the end of the clearing. The road runs NORTH to SOUTH and has no cars in sight.", ... });
	let container = alloc(area {
		name = "Shipping Container",
		dialog = "You make your way up the street and stop next to a rusted out shipping container. The door is open.",
		subarea = ("container floor", "The floor is covered in blood and a human hand holding an old iron key."),
		item = ("old iron key", "You pick up the bloody key and place it into you pocket."),
		...
	});

	adjacent(forest, direction::EAST, streetlight);
	adjacent(streetlight, direction::NORTH, container);

	let m = alloc(map {
		welcome = "+----------------------+\n| Welcome to Ævintýri! |\n+----------------------+\n\n",
		currarea = forest,
		...
	});

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
	return "move <direction>\nlook <direction>\npick <item-name>\nuse <item-name>\nquit\nhelp\nabout";
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