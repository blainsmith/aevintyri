use strings;
use ascii;

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
	HELP,
	ABOUT,
};

export fn parseaction(s: str) (action | invalid) = {
	switch (ascii::strlower(s)) {
	case "move", "m", "walk", "go" => return action::MOVE;
	case "look", "look at" => return action::LOOK;
	case "pick", "take", "grab" => return action::PICK;
	case "use" => return action::USE;
	case "quit", "exit" => return action::QUIT;
	case "help" => return action::HELP;
	case "about" => return action::ABOUT;
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
	case action::HELP => return "help";
	case action::ABOUT => return "about";
	};
};

export type command = (action, str);

export fn parse_input(in: []u8) (command | invalid) = {
	let input = strings::fromutf8(in) as str;
	let (act, args) = strings::cut(input, " ");

	return match(parseaction(act)) {
	case let a: action =>
		yield (a, args);
	case =>
		yield invalid;
	};
};

@test fn parse_input() void = {
	assert(true);
};

export fn exec_command(map: *map, cmd: command) str = {
	switch (cmd.0) {
	case action::MOVE =>
		const d = match (parsedirection(cmd.1)) {
		case let d: direction =>
			move(map, d);
			yield map.currarea.dialog;
		case invalid =>
			yield "Not a direction";
		};
		return d;
	case action::LOOK =>
		const d = match (look(map, cmd.1)) {
		case let d: str =>
			yield d;
		case void =>
			yield "Nothing interesting";
		};
		return d;
	case action::PICK =>
		const i = match (pick(map, cmd.1)) {
		case let i: str =>
			yield i;
		case void =>
			yield "No item around";
		};
		return i;
	case action::USE => return "Not implemented";
	case action::HELP => return help();
	case action::QUIT => return "Not implemented";
	case action::ABOUT => return ABOUT;
	};
};

@test fn exec_command() void = {
	assert(true);
};
