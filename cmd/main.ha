use bytes;
use dirs;
use errors;
use fmt;
use fs;
use getopt;
use io;
use log;
use memio;
use net;
use net::ip;
use net::tcp;
use os;
use strconv;
use strings;
use unix::signal;

use game;

use vendor::bitcask;
use vendor::encoding::json;
use vendor::ev;
use vendor::format::scfg;
use vendor::log::logfmt;

type server = struct {
	loop: *ev::loop,
	sock: *ev::file,
	clients: []*client,
	db: *bitcask::db,
	map: *game::map,
	exit: int,
};

type client = struct {
	server: *server,
	sock: *ev::file,
	addr: ip::addr,
	port: u16,
	input: [os::BUFSZ]u8,

	messages: *game::messageQueue,

	map: *game::map,
	player: nullable *game::player,
};

export fn main() void = {
	const logger = logfmt::new(os::stdout);
	log::setlogger(&logger);

	const cmd = getopt::parse(os::args, "Ævintýri",
		('a', "addr", "host IP address to bind to (default: 0.0.0.0)"),
		('p', "port", "port to listen on (default: 7913)"),
		('s', "script", "script file to load (default: ./scripts/zombie.script)"),
		('d', "dir", "directory to store database files (default: $XDG_DATA_HOME/.local/share/aevintyri)"),
	);
	defer getopt::finish(&cmd);

	let addr: ip::addr = ip::ANY_V4;
	let port: u16 = 7913;
	let script: str = "./scripts/zombie.script";
	let dir: str = dirs::data("aevintyri");
	for (let i = 0z; i < len(cmd.opts); i += 1) {
		const opt = cmd.opts[i];
		switch (opt.0) {
		case 'a' =>
			addr = ip::parse(opt.1)!;
		case 'p' =>
			port = strconv::stou16(opt.1)!;
		case 's' =>
			script = opt.1;
		case 'd' =>
			dir = strings::dup(opt.1);
		case => abort();
		};
	};

	let scriptfile = match (os::open(script)) {
	case let err: fs::error =>
		log::fatalf("error: {}", fs::strerror(err));
	case let f: io::file =>
		yield f;
	};

	let map = match (game::parse(scriptfile)) {
	case let err: scfg::error =>
		log::fatalf("error: {}", scfg::strerror(err));
	case let m: *game::map =>
		yield m;
	};

	let dbopts = bitcask::defaultopts;
	dbopts.dir = dir;
	let db = bitcask::new(dbopts)!;
	defer bitcask::finish(db)!;

	bitcask::merge(db)!;
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
		map = map,
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
		messages = game::newqueue(),
		map = game::map_dup(server.map),
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
		let response = "";

		switch (cmd.0) {
		case game::action::QUIT =>
			client_close(client);
			return;
		case game::action::NICK =>
			response = match(nick(client, cmd.1)) {
			case let p: *game::player =>
				client.player = p;
				yield fmt::asprintf("Welcome, {}!", p.nick);
			case let err: json::error =>
				yield json::strerror(err);
			case let err: bitcask::error =>
				yield bitcask::strerror(err);
			};
		case game::action::SAY =>
			broadcast_message(client, cmd.1);
			response = strings::concat("You say: ", cmd.1);
		case =>
			response = game::exec_command(client.map, cmd);
		};

		let queuesize = game::queuegetsize(client.messages);
		if (queuesize > 0) {
			response = strings::concat(response, "\r\n\r\nYou have new messages:\r\n");
			for (let i = 0z; i < queuesize; i += 1) {
				let msg = game::queueremove(client.messages) as str;
				response = strings::concat(response, "\t- ", msg, "\r\n");
			};
		};

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
	free(client.player);
	free(client);
};


// Broadcasts a message from the given client to all other clients
//
// # Arguments
//
// * `client` - The client saying the message
// * `message` - The message being broadcasted
fn broadcast_message(client: *client, message: str) void = {
	const server = client.server;
	for (let i = 0z; i < len(server.clients); i += 1) {
		if (server.clients[i] != client) {
			if (game::areaequals(server.clients[i].map, client.map)) {
			//fmt::println(message)!;
			game::queueadd(server.clients[i].messages, strings::concat("(", client.map.currarea.name, ") Someone said: ", message));
			};
		};
	};
};

// Callback for Broadcast Message
fn broadcast_cb(sock: *ev::file, r: (size | io::error)) void = {
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
};

fn nick(c: *client, n: str) (*game::player | json::error | bitcask::error) = {
	let p = alloc(game::player { ... });
	
	match (bitcask::get(c.server.db, n)?) {
	case let val: []u8 =>
		game::decode_player(p, &memio::fixed(val))?;
		log::println("scope", "decode_player", "player", p.nick);
	case =>
		p.nick = strings::dup(n);

		let val = memio::dynamic();
		defer io::close(&val)!;

		game::encode_player(p, &val)?;
		bitcask::put(c.server.db, n, memio::buffer(&val))?;
		log::println("scope", "encode_player", "player", p.nick);
	};

	return p;
};
