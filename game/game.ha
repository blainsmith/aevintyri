use log;

export type invalid = !void;

export type error = !invalid;

export type direction = enum {
	NORTH,
	SOUTH,
	EAST,
	WEST,
};

export fn directionstr(d: direction) str = {
	switch (d) {
	case direction::NORTH => return "north";
	case direction::SOUTH => return "south";
	case direction::EAST => return "east";
	case direction::WEST => return "west";
	};
};

export fn parsedirection(s: str) (direction | invalid) = {
	switch (s) {
	case "north", "NORTH" => return direction::NORTH;
	case "south", "SOUTH" => return direction::SOUTH;
	case "east", "EAST" => return direction::EAST;
	case "west", "WEST" => return direction::WEST;
	case => return invalid;
	};
};

@test fn parsedirection() void = {
	assert(parsedirection("north") as direction == direction::NORTH);
	assert(parsedirection("NORTH") as direction == direction::NORTH);
	assert(parsedirection("nope") is invalid);
};

export type action = enum {
	MOVE,
	LOOK,
	PICK,
	USE,
	QUIT,
};

export fn parseaction(s: str) (action | invalid) = {
	switch (s) {
	case "move", "MOVE" => return action::MOVE;
	case "look", "LOOK" => return action::LOOK;
	case "pick", "PICK" => return action::PICK;
	case "use", "USE" => return action::USE;
	case "quit", "QUIT" => return action::QUIT;
	case => return invalid;
	};
};

@test fn parseaction() void = {
	assert(parseaction("look") as action == action::LOOK);
	assert(parseaction("LOOK") as action == action::LOOK);
	assert(parseaction("swim") is invalid);
};

export fn actionstr(a: action) str = {
	switch (a) {
	case action::MOVE => return "move";
	case action::LOOK => return "look";
	case action::PICK => return "pick";
	case action::USE => return "use";
	case action::QUIT => return "quit";
	};
};

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