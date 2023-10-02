use endian;
use hash;
use hash::crc32;
use hash::fnv;
use log;
use strings;
use time;

def HDRSZ: size = 28;

type header = struct {
	cksum: u32,
	ts: time::instant,
	expiry: time::instant,
	keysz: size,
	valsz: size,
};

fn header_encode(out: []u8, in: *header) void = {
	endian::little.putu32(out[0..4], in.cksum);
	endian::little.putu64(out[4..12], unixnano(in.ts): u64);
	endian::little.putu64(out[12..20], unixnano(in.expiry): u64);
	endian::little.putu32(out[20..24], in.keysz: u32);
	endian::little.putu32(out[24..28], in.valsz: u32);
};

fn header_decode(out: *header, in: []u8) void = {
	out.cksum = endian::little.getu32(in[0..4]);
	out.ts = from_unixnano(0, endian::little.getu64(in[4..12]): i64);
	out.expiry = from_unixnano(0, endian::little.getu64(in[12..20]): i64);
	out.keysz = endian::little.getu32(in[20..24]): size;
	out.valsz = endian::little.getu32(in[24..28]): size;
};

type record = struct {
	hdr: header,
	key: str,
	val: []u8,
};

fn record_encode(out: []u8, r: *record) void = {
	header_encode(out, &r.hdr);

	let kend = HDRSZ + r.hdr.keysz;
	let vend = kend + r.hdr.valsz;
	out[HDRSZ..kend] = strings::toutf8(r.key);
	out[kend..vend] = r.val;
};

fn record_decode(out: *record, in: []u8) void = {
	header_decode(&out.hdr, in);

	let kend = HDRSZ + out.hdr.keysz;
	let vend = kend + out.hdr.valsz;
	out.key = strings::fromutf8_unsafe(in[HDRSZ..kend]);
	out.val = in[kend..vend];
};

fn record_expired(rec: *record) bool = {
	let now = time::now(time::clock::REALTIME);
	return (time::compare(now, rec.hdr.expiry) > 0);
};

fn record_valid(rec: *record) bool = {
	let crc_ieee = crc32::crc32(&hash::crc32::ieee_table);
	hash::reset(&crc_ieee);
	hash::write(&crc_ieee, rec.val);
	return (crc32::sum32(&crc_ieee) == rec.hdr.cksum);
};
