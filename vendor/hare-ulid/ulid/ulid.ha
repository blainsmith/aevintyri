use bufio;
use bytes;
use crypto::random;
use fmt;
use io;
use strings;
use strio;
use time;

export type ulid = [16]u8;

export def ULID_STRLEN: size = 26;

export def ULID_URILEN: size = 35;

export const nil: ulid = [0...];

export type invalid = !void;

const encoding: [32]rune = [
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
	'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'X', 'Y', 'Z'
];

const decoding: [_]u8 = [
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x01,
	0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
	0x0F, 0x10, 0x11, 0xFF, 0x12, 0x13, 0xFF, 0x14, 0x15, 0xFF,
	0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C, 0x1D, 0x1E,
	0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0A, 0x0B, 0x0C,
	0x0D, 0x0E, 0x0F, 0x10, 0x11, 0xFF, 0x12, 0x13, 0xFF, 0x14,
	0x15, 0xFF, 0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C,
	0x1D, 0x1E, 0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
];

export fn generate() ulid = {
	let id: ulid = [0...];
	random::buffer(id[6..]);

	let n = time::now(time::clock::REALTIME);
	let ms = n.sec: u64 * 1000 + (n.nsec / time::MILLISECOND): u64;

	id[0] = (ms >> 40): u8;
	id[1] = (ms >> 32): u8;
	id[2] = (ms >> 24): u8;
	id[3] = (ms >> 16): u8;
	id[4] = (ms >> 8): u8;
	id[5] = (ms): u8;

	return id;
};

export fn compare(a: ulid, b: ulid) bool = bytes::equal(a, b);

export fn encode(out: io::handle, id: ulid) (size | io::error) = {
	let z = 0z;

	z += fmt::fprint(out, encoding[(id[0]&224)>>5])?;
	z += fmt::fprint(out, encoding[id[0]&31])?;
	z += fmt::fprint(out, encoding[(id[1]&248)>>3])?;
	z += fmt::fprint(out, encoding[((id[1]&7)<<2)|((id[2]&192)>>6)])?;
	z += fmt::fprint(out, encoding[(id[2]&62)>>1])?;
	z += fmt::fprint(out, encoding[((id[2]&1)<<4)|((id[3]&240)>>4)])?;
	z += fmt::fprint(out, encoding[((id[3]&15)<<1)|((id[4]&128)>>7)])?;
	z += fmt::fprint(out, encoding[(id[4]&124)>>2])?;
	z += fmt::fprint(out, encoding[((id[4]&3)<<3)|((id[5]&224)>>5)])?;
	z += fmt::fprint(out, encoding[id[5]&31])?;

	z += fmt::fprint(out, encoding[(id[6]&248)>>3])?;
	z += fmt::fprint(out, encoding[((id[6]&7)<<2)|((id[7]&192)>>6)])?;
	z += fmt::fprint(out, encoding[(id[7]&62)>>1])?;
	z += fmt::fprint(out, encoding[((id[7]&1)<<4)|((id[8]&240)>>4)])?;
	z += fmt::fprint(out, encoding[((id[8]&15)<<1)|((id[9]&128)>>7)])?;
	z += fmt::fprint(out, encoding[(id[9]&124)>>2])?;
	z += fmt::fprint(out, encoding[((id[9]&3)<<3)|((id[10]&224)>>5)])?;
	z += fmt::fprint(out, encoding[id[10]&31])?;
	z += fmt::fprint(out, encoding[(id[11]&248)>>3])?;
	z += fmt::fprint(out, encoding[((id[11]&7)<<2)|((id[12]&192)>>6)])?;
	z += fmt::fprint(out, encoding[(id[12]&62)>>1])?;
	z += fmt::fprint(out, encoding[((id[12]&1)<<4)|((id[13]&240)>>4)])?;
	z += fmt::fprint(out, encoding[((id[13]&15)<<1)|((id[14]&128)>>7)])?;
	z += fmt::fprint(out, encoding[(id[14]&124)>>2])?;
	z += fmt::fprint(out, encoding[((id[14]&3)<<3)|((id[15]&224)>>5)])?;
	z += fmt::fprint(out, encoding[id[15]&31])?;

	return z;
};

export fn uri(out: io::handle, in: ulid) (size | io::error) = {
	return fmt::fprintf(out, "urn:ulid:")? + encode(out, in)?;
};

export fn encodestr(id: ulid) str = {
	static let buf: [ULID_STRLEN]u8 = [0...];
	let sink = strio::fixed(buf);
	encode(&sink, id) as size;
	return strio::string(&sink);
};

export fn encodeuri(in: ulid) str = {
	static let buf: [ULID_URILEN]u8 = [0...];
	let sink = strio::fixed(buf);
	uri(&sink, in) as size;
	return strio::string(&sink);
};

export fn decode(in: io::handle) (ulid | invalid | io::error) = {
	let id: ulid = [0...];
	static let buf: [ULID_STRLEN]u8 = [0...];

	io::read(in, buf)?;
	
	id[0] = (decoding[buf[0]]<<5) | decoding[buf[1]];
	id[1] = (decoding[buf[2]] << 3) | (decoding[buf[3]] >> 2);
	id[2] = (decoding[buf[3]] << 6) | (decoding[buf[4]] << 1)
			| (decoding[buf[5]] >> 4);
	id[3] = (decoding[buf[5]] << 4) | (decoding[buf[6]] >> 1);
	id[4] = (decoding[buf[6]] << 7) | (decoding[buf[7]] << 2)
			| (decoding[buf[8]] >> 3);
	id[5] = (decoding[buf[8]] << 5) | decoding[buf[9]];

	id[6] = (decoding[buf[10]] << 3) | (decoding[buf[11]] >> 2);
	id[7] = (decoding[buf[11]] << 6) | (decoding[buf[12]] << 1)
			| (decoding[buf[13]] >> 4);
	id[8] = (decoding[buf[13]] << 4) | (decoding[buf[14]] >> 1);
	id[9] = (decoding[buf[14]] << 7) | (decoding[buf[15]] << 2)
			| (decoding[buf[16]] >> 3);
	id[10] = (decoding[buf[16]] << 5) | decoding[buf[17]];
	id[11] = (decoding[buf[18]] << 3) | decoding[buf[19]]>>2;
	id[12] = (decoding[buf[19]] << 6) | (decoding[buf[20]] << 1)
			| (decoding[buf[21]] >> 4);
	id[13] = (decoding[buf[21]] << 4) | (decoding[buf[22]] >> 1);
	id[14] = (decoding[buf[22]] << 7) | (decoding[buf[23]] << 2)
			| (decoding[buf[24]] >> 3);
	id[15] = (decoding[buf[24]] << 5) | decoding[buf[25]];
	
	return id;
};

export fn decodestr(in: str) (ulid | invalid) = {
	let buf = bufio::fixed(strings::toutf8(in), io::mode::READ);
	match (decode(&buf)) {
	case let err: io::error =>
		abort();
	case invalid =>
		return invalid;
	case let u: ulid =>
		return u;
	};
};

@test fn ulid() void = {
	let id = generate();
	let encid = encodestr(id);
	let decid = decodestr(encid)!;
	assert(compare(id, decid));
};