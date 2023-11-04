// License: MPL-2.0
// (c) 2022-2023 Chris Palmer <chris@red-oxide.org>
use bufio;
use io;
use os;
use shlex;
use strings;

// Creates a scfg scanner. Use [[next]] to read directives. The caller must call
// [[finish]] once they're done with this object.
export fn scan(in: io::handle) scanner = scanner {
	in = in,
	...
};


// Scans and returns the next [[directive]].
export fn next(s: *scanner) (directive | io::EOF | error) = {
	for(true) {
		s.lineno += 1;

		const line = match (bufio::read_line(s.in)?) {
		case let b: []u8 =>
			yield strings::fromutf8(b)?;
		case io::EOF =>
			if (len(s.blocks) > 0) {
				return s.lineno: syntaxerr;
			};
			return io::EOF;
		};

		free(s.line);
		s.line = line;

		const line = strings::trim(s.line);

		if (len(s.line) == 0 || strings::hasprefix(s.line, "#")) {
			continue;
		};

		if (line == "}") {
			const bl = len(s.blocks);
			if (bl == 0) {
				return s.lineno: syntaxerr;
			};

			delete(s.blocks[bl - 1]);

			continue;
		};

		const sline = shlex::split(line)?;
		defer strings::freeall(sline);

		if (len(sline) < 2) {
			return s.lineno: syntaxerr;
		};

		free(s.params);
		s.params = [];

		s.name = strings::dup(sline[0]);
		let haschild = false;
		for (let i = 1z; i < len(sline); i += 1) {
			const v = sline[i];
			if (v == "{") {
				if (i < len(sline) - 1) {
					return s.lineno: syntaxerr;
				};

				haschild = true;
				break;
			} else {
				append(s.params, strings::dup(v));
			};
		};

		defer if (haschild) {
			append(s.blocks, strings::dup(s.name));
		};


		const bl = len(s.blocks);
		if (bl == 0) {
			return (
				"",
				s.name,
				s.params,
			);
		} else {
			return (
				s.blocks[bl - 1],
				s.name,
				s.params,
			);
		};
	};
	abort(); //Unreachable
};

// Frees the resources associated with a [[scanner]].
export fn finish(s: *scanner) void = {
	free(s.line);
	free(s.name);
	free(s.params);
	free(s.blocks);
};
