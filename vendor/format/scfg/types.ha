// License: MPL-2.0
// (c) 2022-2023 Chris Palmer <chris@red-oxide.org>
use bufio;
use encoding::utf8;
use fmt;
use io;
use os;
use shlex;
use strings;

export type scanner = struct{
	in: io::handle,
	lineno: uint,
	line: str,
	name: str,
	params: []str,
	blocks: []str,
};

// A directive in a scfg file: (block, name, parameters).
export type directive = (const str, const str, const []str);

// Duplicates a [[directive]]. Use [[directive_finish]] to get rid of it.
export fn directive_dup(d: directive) directive = (
	strings::dup(d.0),
	strings::dup(d.1),
	d.2,
);

// Frees a [[directive]] previously duplicated with [[directive_dup]].
export fn directive_finish(d: directive) void = {
	free(d.0);
	free(d.1);
	free(d.2);
};

// A syntax error occured during parsing
export type syntaxerr = !size;

// Any error which can occur during scfg parsing.
export type error = !(io::error | syntaxerr | utf8::invalid | shlex::syntaxerr);

// Convert an [[error]] to a user-friendly string representation.
export fn strerror(err: error) const str = match (err) {
	case let s: syntaxerr =>
		static let buf: [1024]u8 = [0...];
		yield fmt::bsprintf(buf, "{} Invalid syntax", s: size);
	case shlex::syntaxerr =>
		yield "Syntax error";
	case utf8::invalid =>
		yield "Document is not valid UTF-8";
	case let err: io::error =>
		yield io::strerror(err);
};
