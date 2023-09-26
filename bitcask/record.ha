use endian;
use hash;
use hash::crc32;
use hash::fnv;
use log;
use time;

export type header = struct {
	cksum: u32,
	ts: time::instant,
	expiry: time::instant,
	keysz: size,
	valsz: size,
};

export fn header_encode(out: []u8, in: *header) void = {
	endian::little.putu32(out[0..4], in.cksum);
	endian::little.putu64(out[4..12], time::unix(in.ts): u64);
	endian::little.putu64(out[12..20], time::unix(in.expiry): u64);
	endian::little.putu32(out[20..24], in.keysz: u32);
	endian::little.putu32(out[24..28], in.valsz: u32);
};

export fn header_decode(out: *header, in: []u8) void = {
	out.cksum = endian::little.getu32(in[0..4]);
	out.ts = time::from_unix(endian::little.getu64(in[4..12]): i64);
	out.expiry = time::from_unix(endian::little.getu64(in[12..20]): i64);
	out.keysz = endian::little.getu32(in[20..24]): size;
	out.valsz = endian::little.getu32(in[24..28]): size;
};

export type record = struct {
	hdr: header,
	key: str,
	val: []u8,
};

export fn record_expired(rec: *record) bool = {
	let now = time::now(time::clock::REALTIME);
	return (time::compare(now, rec.hdr.expiry) > 0);
};

@test fn record_expired() void = {
	let r = record {
		hdr = header {
			cksum = 0,
			ts = time::from_unix(0),
			expiry = time::from_unix(12345),
			...
		},
		...
	};
	assert(record_expired(&r));

	r.hdr.expiry = time::add(time::now(time::clock::REALTIME), 5 * time::HOUR);
	assert(!record_expired(&r));
};

export fn record_valid(rec: *record) bool = {
	let crc_ieee = crc32::crc32(&hash::crc32::ieee_table);
	hash::reset(&crc_ieee);
	hash::write(&crc_ieee, rec.val);
	return (crc32::sum32(&crc_ieee) == rec.hdr.cksum);
};

@test fn record_valid() void = {
	let val: []u8 = ['k', 'e', 'y', 'v', 'a', 'l'];
	let crc_ieee = crc32::crc32(&hash::crc32::ieee_table);
	hash::reset(&crc_ieee);
	hash::write(&crc_ieee, val);

	let r = record {
		hdr = header {
			cksum = crc32::sum32(&crc_ieee),
			...
		},
		key = "",
		val = val,
		...
	};
	assert(record_valid(&r));

	r.hdr.cksum += 1;
	assert(!record_valid(&r));
};

