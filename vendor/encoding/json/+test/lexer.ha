use io;
use memio;
use strings;

@test fn lex() void = {
	const cases: [_](str, []token) = [
		("true", [true]),
		("false", [false]),
		("null", [_null]),
		("1234", [1234.0]),
		("12.34", [12.34]),
		("12.34e5", [12.34e5]),
		("12.34E5", [12.34e5]),
		("12.34e+5", [12.34e5]),
		("12.34e-5", [12.34e-5]),
		("12e5", [12.0e5]),
		("-1234", [-1234.0]),
		(`"hello world"`, ["hello world"]),
		(`"\"\\\/\b\f\n\r\t\u0020"`, ["\"\\/\b\f\n\r\t\u0020"]),
		("[ null, null ]", [arraystart, _null, comma, _null, arrayend]),
	];

	for (let i = 0z; i < len(cases); i += 1) {
		const src = strings::toutf8(cases[i].0);
		const src = memio::fixed(src);
		const lexer = newlexer(&src);
		defer close(&lexer);

		for (let j = 0z; j < len(cases[i].1); j += 1) {
			const want = cases[i].1[j];
			const have = lex(&lexer)! as token;
			assert(tokeq(want, have));
		};

		assert(lex(&lexer) is io::EOF);
	};
};

fn tokeq(want: token, have: token) bool = {
	match (want) {
	case _null =>
		return have is _null;
	case comma =>
		return have is comma;
	case colon =>
		return have is colon;
	case arraystart =>
		return have is arraystart;
	case arrayend =>
		return have is arrayend;
	case objstart =>
		return have is objstart;
	case objend =>
		return have is objend;
	case let b: bool =>
		return have as bool == b;
	case let f: f64 =>
		return have as f64 == f;
	case let s: str =>
		return have as str == s;
	};
};
