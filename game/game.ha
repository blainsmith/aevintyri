use io;

export type action = enum {
	MOVE,
	LOOK,
	PICK,
	USE,
	QUIT,
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

export type trigger = fn(w: int, a: action, args: []str) void;

export type area = struct {
	name: str,
	desc: str,

	actions: [](action, *trigger),
};