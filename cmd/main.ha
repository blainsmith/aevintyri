use errors;
use ev;
use getopt;
use io;
use log;
use log::logfmt;
use net;
use net::ip;
use net::tcp;
use os;
use strconv;
use strings;
use unix::signal;

type server = struct {
	loop: *ev::loop,
	sock: *ev::file,
	welcome: []u8,
	prompt: []u8,
	clients: []*client,
	exit: int,
};

type client = struct {
	server: *server,
	sock: *ev::file,
	addr: ip::addr,
	port: u16,
	buf: [os::BUFSZ]u8,
	wbuf: []u8,
};

export fn main() void = {
	const logger = logfmt::new(os::stdout);
	log::setlogger(&logger);

	const cmd = getopt::parse(os::args, "Ævintýri",
		('a', "addr", "host IP address to bind to (default: 0.0.0.0)"),
		('p', "port", "port to listen on (default: 7913)"),
	);
	defer getopt::finish(&cmd);

	let addr: ip::addr = ip::ANY_V4;
	let port: u16 = 7913;
	for (let i = 0z; i < len(cmd.opts); i += 1) {
		const opt = cmd.opts[i];
		switch (opt.0) {
		case 'a' =>
			addr = ip::parse(opt.1)!;
		case 'p' =>
			port = strconv::stou16(opt.1)!;
		case => abort();
		};
	};

	const loop = ev::newloop()!;
	defer ev::finish(&loop);

	const sock = match (ev::listen_tcp(&loop, addr, port)) {
	case let err: net::error =>
		log::fatalf("error", net::strerror(err));
	case let err: errors::error =>
		log::fatalf("error", errors::strerror(err));
	case let sock: *ev::file =>
		yield sock;
	};
	defer ev::close(sock);

	let state = server {
		loop = &loop,
		sock = sock,
		welcome = strings::toutf8("+----------------------+\n| Welcome to Ævintýri! |\n+----------------------+\n\n» "),
		prompt = alloc(['»', ' ']),
		...
	};
	ev::setuser(sock, &state);
	ev::accept(sock, &server_accept);

	const sig = ev::signal(&loop, &signal, signal::sig::INT, signal::sig::TERM)!;
	defer ev::close(sig);
	ev::setuser(sig, &state);

	log::println("addr", ip::string(addr), "port", port);
	for (ev::dispatch(&loop, -1)!) void;
	os::exit(state.exit);
};

fn signal(file: *ev::file, sig: signal::sig) void = {
	log::printfln("signal", signal::signame(sig));
	const server = ev::getuser(file): *server;
	ev::stop(server.loop);
};

fn server_accept(sock: *ev::file, r: (*ev::file | net::error)) void = {
	let server = ev::getuser(sock): *server;
	const sock = match (r) {
	case let sock: *ev::file =>
		yield sock;
	case let err: net::error =>
		log::printfln("error", net::strerror(err));
		ev::stop(server.loop);
		server.exit = 1;
		return;
	};
	const file = ev::getfd(sock);
	const (addr, port) = tcp::peeraddr(file) as (ip::addr, u16);
	log::printfln("Connection from {}:{}", ip::string(addr), port);

	const client = alloc(client {
		server = server,
		sock = sock,
		addr = addr,
		port = port,
		...
	});
	append(server.clients, client);
	ev::setuser(client.sock, client);
	ev::write(client.sock, &client_welcome, server.welcome);
	ev::read(client.sock, &client_read, client.buf);
	ev::accept(server.sock, &server_accept);
};

fn client_read(sock: *ev::file, r: (size | io::EOF | io::error)) void = {
	const client = ev::getuser(sock): *client;
	const n = match (r) {
	case let err: io::error =>
		log::printfln("client_addr", ip::string(client.addr),
			"client_port", client.port,
			"error", io::strerror(err));
		client_close(client);
		return;
	case io::EOF =>
		client_close(client);
		return;
	case let n: size =>
		yield n;
	};
	client.wbuf = client.buf[..n];
	ev::write(client.sock, &client_write, client.wbuf);
};

fn client_welcome(sock: *ev::file, r: (size | io::error)) void = {
	return;
};

fn client_write(sock: *ev::file, r: (size | io::error)) void = {
	const client = ev::getuser(sock): *client;
	const n = match (r) {
	case let err: io::error =>
		log::printfln("{}:{}: Error: write: {}",
			ip::string(client.addr), client.port,
			io::strerror(err));
		client_close(client);
		return;
	case let n: size =>
		yield n;
	};
	static delete(client.wbuf[..n]);
	if (len(client.wbuf) != 0) {
		ev::write(client.sock, &client_write, client.wbuf);
	} else {
		ev::read(client.sock, &client_read, client.buf);
	};
};

fn client_close(client: *client) void = {
	const server = client.server;
	for (let i = 0z; i < len(server.clients); i += 1) {
		if (server.clients[i] == client) {
			delete(server.clients[i]);
			break;
		};
	};
	log::printfln("{}:{}: Connection closed",
		ip::string(client.addr), client.port);
	ev::close(client.sock);
	free(client);
};
