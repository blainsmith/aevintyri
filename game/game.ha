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

export fn parsedirection(s: str) direction = {
	switch (s) {
	case "north" => return direction::NORTH;
	case "south" => return direction::SOUTH;
	case "east" => return direction::EAST;
	case "west" => return direction::WEST;
	};
};

export type action = enum {
	MOVE,
	LOOK,
	PICK,
	USE,
	QUIT,
};

export fn parseaction(s: str) action = {
	switch (s) {
	case "move" => return action::MOVE;
	case "look" => return action::LOOK;
	case "pick" => return action::PICK;
	case "use" => return action::USE;
	case "quit" => return action::QUIT;
	};
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
	currarea: *area,
	inventory: []str,
};

export type area = struct {
	name: str,
	dialog: str,

	adjacent: [](direction, *area),

	actions: [](action, str),
};

export fn move(m: *map, d: direction) void = {
	for (let i = 0z; i < len(m.currarea.adjacent); i += 1) {
		if (m.currarea.adjacent[i].0 == d) {
			m.currarea = m.currarea.adjacent[i].1;
		};
	};

	return;
};

@test fn move() void = {
	let forest = area { name = "Wooded Forest", dialog = "You find yourself alone in a wooded forest. To the EAST you see a dim light.", ... };
	let streetlight = area { name = "Street Light", dialog = "After walking through the forest you come to a clearing and come upon a street light at the end of the clearing. The road runs EAST to WEST and has no cars in sight.", ... };

	append(forest.adjacent, (direction::EAST, &streetlight));

	let m = map { currarea = &forest, ... };
	assert(m.currarea.name == "Wooded Forest");

	move(&m, direction::EAST);
	assert(m.currarea.name == "Street Light");
};