use fs;
use os;
use strings;

use vendor::format::scfg;

use log;

export fn mapsinit(dir: str) ([](str, *map) | fs::error | scfg::error | error) = {
	let maps: [](str, *map) = alloc([], 0);

	const iter = os::iter(dir)?;

	for (true) {
		match (fs::next(iter)) {
		case let ent: fs::dirent =>
			const path = strings::join("/", dir, ent.name);

			let map = parse(os::open(path)?)?;

			append(maps, (strings::dup(ent.name), map));
		case =>
			break;
		};
	};

	return maps;
};

@test fn mapsinit() void = {
	const maps = mapsinit("./scripts");
	assert(maps is [](str, *map));
};
