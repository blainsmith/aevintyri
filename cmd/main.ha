use bytes;
use dirs;
use errors;
use getopt;
use io;
use log;
use net;
use net::ip;
use net::tcp;
use os;
use strconv;
use strings;
use unix::signal;

use game;

use vendor::bitcask;
use vendor::ev;
use vendor::log::logfmt;

type server = struct {
	loop: *ev::loop,
	sock: *ev::file,
	clients: []*client,
	db: *bitcask::db,
	exit: int,
};

type client = struct {
	server: *server,
	sock: *ev::file,
	addr: ip::addr,
	port: u16,
	input: [os::BUFSZ]u8,

	map: *game::map,
;

export fn main() void = {
	const logger = logfmt::new(os::stdout);
	log::setlogger(&logger);

	const cmd = getopt::parse(os::args, "Ævintýri",
		('a', "addr", "host IP address to bind to (default: 0.0.0.0)"),
		('p', "port", "port to listen on (default: 7913)"),
		('d', "dir", "directory to store database files (default: $XDG_DATA_HOME/.local/share/aevintyri)")
	);
	defer getopt::finish(&cmd);

	let addr: ip::addr = ip::ANY_V4;
	let port: u16 = 7913;
	let dir: str = dirs::data("aevintyri");
	for (let i = 0z; i < len(cmd.opts); i += 1) {
		const opt = cmd.opts[i];
		switch (opt.0) {
		case 'a' =>
			addr = ip::parse(opt.1)!;
		case 'p' =>
			port = strconv::stou16(opt.1)!;
		case 'd' =>
			dir = strings::dup(opt.1);
		case => abort();
		};
	};

	let dbopts = bitcask::defaultopts;
	dbopts.dir = dir;
	let db = bitcask::new(dbopts)!;
	defer bitcask::finish(db)!;
	log::println("dir", dbopts.dir);

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
		db = db,
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
	log::println("signal", signal::signame(sig));
	const server = ev::getuser(file): *server;
	ev::stop(server.loop);
};

fn server_accept(sock: *ev::file, r: (*ev::file | net::error)) void = {
	let server = ev::getuser(sock): *server;
	const sock = match (r) {
	case let sock: *ev::file =>
		yield sock;
	case let err: net::error =>
		log::println("scope", "server_accept", "error", net::strerror(err));
		ev::stop(server.loop);
		server.exit = 1;
		return;
	};
	const file = ev::getfd(sock);
	const (addr, port) = tcp::peeraddr(file) as (ip::addr, u16);
	log::println("client_addr", ip::string(addr), "client_port", port);

	const client = alloc(client {
		server = server,
		sock = sock,
		addr = addr,
		port = port,
		map = game::newmap(),
		...
	});
	append(server.clients, client);
	ev::setuser(client.sock, client);
	ev::write(client.sock, &client_noop, strings::toutf8(strings::concat(client.map.welcome, client.map.currarea.dialog, game::PROMPT)));
	ev::read(client.sock, &client_read, client.input);
	ev::accept(server.sock, &server_accept);
};

fn client_read(sock: *ev::file, r: (size | io::EOF | io::error)) void = {
	const client = ev::getuser(sock): *client;
	const n = match (r) {
	case let err: io::error =>
		log::println("scope", "client_read",
			"client_addr", ip::string(client.addr),
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

	let in = bytes::rtrim(client.input[..n], '\r', '\n');

	match (game::parse_input(in)) {
	case let cmd: game::command =>
		if (cmd.0 == game::action::QUIT) {
			client_close(client);
			return;
		};

		let response = game::exec_command(client.map, cmd);
		ev::write(client.sock, &client_write, strings::toutf8(strings::concat(response, game::PROMPT)));
	case =>
		ev::write(client.sock, &client_write, strings::toutf8(strings::concat("No idea what that means", game::PROMPT)));
	};
};

fn client_noop(sock: *ev::file, r: (size | io::error)) void = {
	return;
};

fn client_write(sock: *ev::file, r: (size | io::error)) void = {
	const client = ev::getuser(sock): *client;
	const n = match (r) {
	case let err: io::error =>
		log::println("scope", "client_write",
			"client_addr", ip::string(client.addr),
			"client_port", client.port,
			"error", io::strerror(err));
		client_close(client);
		return;
	case let n: size =>
		yield n;
	};

	ev::read(client.sock, &client_read, client.input);
};

fn client_close(client: *client) void = {
	const server = client.server;
	for (let i = 0z; i < len(server.clients); i += 1) {
		if (server.clients[i] == client) {
			delete(server.clients[i]);
			break;
		};
	};
	log::println("scope", "client_close",
		"client_addr", ip::string(client.addr),
		"client_port", client.port);
	ev::close(client.sock);
	free(client.map.currarea.adjacent);
	free(client.map.currarea);
	free(client);
};
