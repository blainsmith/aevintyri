use hash;
use hash::crc32;
use time;

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
