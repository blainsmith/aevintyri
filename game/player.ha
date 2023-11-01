use io;
use strings;

use vendor::encoding::json;

export type player = struct {
	nick: str,
};

export fn encode_player(p: *player, out: io::handle) (void | json::error) = {
	let obj = json::newobject();
	defer json::finish(obj);

	json::set(&obj, "nick", p.nick);

	json::dump(out, obj)?;
};

export fn decode_player(p: *player, in: io::handle) (void | json::error) = {
	let obj = json::load(in)? as json::object;
	defer json::finish(obj);

	p.nick = strings::dup(*(json::get(&obj, "nick") as *json::value) as str);
};