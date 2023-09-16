use strings;

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
	};
};

@test fn exec_command() void = {
	assert(true);
};
