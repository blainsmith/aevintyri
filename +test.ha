use log;
use io;
use os;
use strings;
use fmt;

@test fn logfmt() void = {
	let s = teststream_open();

	let l = new(&s);

	log::setlogger(&l);
	log::println("request_uri", "/", "method", "POST", "user_id", 123);

	let sbuf = strings::fromutf8(s.buf)!;

	assert(strings::contains(sbuf, "request_uri=/ method=POST user_id=123"));

	free(sbuf);
};

const teststream_vtable: io::vtable = io::vtable {
	reader = &teststream_read,
	writer = &teststream_write,
	...
};

type teststream = struct {
	stream: io::stream,
	buf: []u8,
};

fn teststream_open() teststream = teststream {
	stream = &teststream_vtable,
	...
};

fn teststream_read(s: *io::stream, buf: []u8) (size | io::EOF | io::error) = {
	let stream = s: *teststream;
	buf = stream.buf;
	return len(buf);
};

fn teststream_write(s: *io::stream, buf: const []u8) (size | io::error) = {
	let stream = s: *teststream;
	append(stream.buf, buf...);
	return len(buf);
};