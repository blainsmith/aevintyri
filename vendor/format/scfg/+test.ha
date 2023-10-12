// License: MPL-2.0
// (c) 2022-2023 Chris Palmer <chris@red-oxide.org>
use encoding::utf8;
use fmt;
use io;
use memio;
use strings;

@test fn simple() void = {
	const buf = memio::fixed(strings::toutf8(
"train Shinkansen {
	model E5 {
		max-speed 320km/h
		weight 453.5t
		lines-served Tōhoku Hokkaido
	}
	model E7 {
		max-speed 275km/h
		weight 540t
		lines-served Hokuriku Jōetsu
	}
}
# Comment
test 1 #2"));
	const s = scan(&buf);
	defer finish(&s);

	directive_test(&s, "", "train", ["Shinkansen"]);
	directive_test(&s, "train", "model", ["E5"]);
	directive_test(&s, "model", "max-speed", ["320km/h"]);
	directive_test(&s, "model", "weight", ["453.5t"]);
	directive_test(&s, "model", "lines-served", ["Tōhoku", "Hokkaido"]);
	directive_test(&s, "train", "model", ["E7"]);
	directive_test(&s, "model", "max-speed", ["275km/h"]);
	directive_test(&s, "model", "weight", ["540t"]);
	directive_test(&s, "model", "lines-served", ["Hokuriku", "Jōetsu"]);
	directive_test(&s, "", "test", ["1", "#2"]);
	assert(next(&s) is io::EOF);
};

@test fn value_after_open() void = {
	const buf = memio::fixed(strings::toutf8(
"name { what"));
	const s = scan(&buf);
	defer finish(&s);

	assert(next(&s) as error is syntaxerr);
};

@test fn missing_name() void = {
	const buf = memio::fixed(strings::toutf8(
"{
	test 1 2 3
}"));
	const s = scan(&buf);
	defer finish(&s);

	assert(next(&s) as error is syntaxerr);
};

@test fn only_name() void = {
	const buf = memio::fixed(strings::toutf8(
"name"));
	const s = scan(&buf);
	defer finish(&s);

	assert(next(&s) as error is syntaxerr);
};

@test fn close_missing() void = {
	const buf = memio::fixed(strings::toutf8(
"name {"));
	const s = scan(&buf);
	defer finish(&s);

	assert(next(&s) is directive);
	assert(next(&s) as error is syntaxerr);
};

@test fn open_missing() void = {
	const buf = memio::fixed(strings::toutf8(
"}"));
	const s = scan(&buf);
	defer finish(&s);

	assert(next(&s) as error is syntaxerr);
};

fn directive_test(
	s: *scanner,
	block: const str,
	name: const str,
	params: const []str,
) void = {
	const d = next(s)! as directive;

	fmt::printfln("\nblock:\n\texpected: {}\n\t  actual: {}", block, d.0)!;
	assert(d.0 == block);

	fmt::printfln("\nname:\n\texpected: {}\n\t  actual: {}", name, d.1)!;
	assert(d.1 == name);

	fmt::printfln("params size:\n\texpected: {}\n\t  actual: {}", len(params),
		len(d.2))!;
	assert(len(d.2) == len(params));

	for (let i = 0z; i < len(params); i += 1) {
		fmt::printfln("params[{}]:\n\texpected: {}\n\t  actual: {}", i,
			params[i], d.2[i])!;
		assert(d.2[i] == params[i]);
	};
};
