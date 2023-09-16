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

use vendor::ev;
use vendor::log::logfmt;

type server = struct {
	loop: *ev::loop,
	sock: *ev::file,
	prompt: str,
	clients: []*client,
	exit: int,
};

type client = struct {
	server: *server,
	sock: *ev::file,
	addr: ip::addr,
	port: u16,
	input: [os::BUFSZ]u8,

	map: *game::map,
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

	static let prompt = "\n\n» ";
	let state = server {
		loop = &loop,
		sock = sock,
		prompt = prompt,
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
	ev::write(client.sock, &client_noop, strings::toutf8(strings::concat(client.map.welcome, client.map.currarea.dialog, server.prompt)));
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

	let input = strings::fromutf8(client.input[..(n-2)]) as str;
	let (action, args) = strings::cut(input, " ");

	log::println("action", action, "actionlen", len(action), "args", args, "argslen", len(args));

	match (game::parseaction(action)) {
	case let a: game::action =>
		switch (a) {
		case game::action::MOVE =>
			const d = match (game::parsedirection(args)) {
			case let d: game::direction =>
				game::move(client.map, d);
				yield client.map.currarea.dialog;
			case game::invalid =>
				yield "Not a direction";
			};

			ev::write(client.sock, &client_write, strings::toutf8(strings::concat(d: str, client.server.prompt)));
		case game::action::LOOK =>
			const d = match (game::look(client.map, args)) {
			case let d: str =>
				yield d;
			case void =>
				yield "Nothing interesting";
			};
			ev::write(client.sock, &client_write, strings::toutf8(strings::concat(d, client.server.prompt)));
		case game::action::PICK =>
			const i = match (game::pick(client.map, args)) {
			case let i: str =>
				yield i;
			case void =>
				yield "No item around";
			};
			ev::write(client.sock, &client_write, strings::toutf8(strings::concat(i, client.server.prompt)));
		case game::action::USE => ev::write(client.sock, &client_write, strings::toutf8(strings::concat("Not implemented", client.server.prompt)));
		case game::action::QUIT => client_close(client);
		case game::action::HELP => ev::write(client.sock, &client_write, strings::toutf8(strings::concat(game::help(), client.server.prompt)));
		};
	case => ev::write(client.sock, &client_write, strings::toutf8(strings::concat("No idea what that means", client.server.prompt)));
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
