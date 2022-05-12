use io;
use log;
use fmt;
use datetime;
use os;
use encoding::utf8;
use strings;

// Implements the log::logger for outputting logs in Logfmt format.
export type logfmtlogger = struct {
	log::logger,
	handle: io::handle,
};

// creates a new instace of logfmtlogger to be use with [[log::setlogger]].
export fn new(handle: io::handle) logfmtlogger = {
	return logfmtlogger {
		println = &log_println,
		printfln = &log_printfln,
		handle = handle,
	};
};

fn log_println(logger: *log::logger, fields: fmt::formattable...) void = {
	const logger = logger: *logfmtlogger;
	assert(logger.println == &log_println);

	const now = datetime::now();
	fmt::fprint(logger.handle, "ts="): void;
	datetime::format(logger.handle, datetime::RFC3339, &now): void;
	fmt::fprint(logger.handle, " "): void;

	for (let i = 0z; i < len(fields); i+= 1) {
		if (i % 2 == 0) {
			fmt::fprint(logger.handle, fields[i]): void;
			fmt::fprint(logger.handle, "="): void;
		} else {
			fmt::fprint(logger.handle, fields[i]): void;
			fmt::fprint(logger.handle, " "): void;
		};
	};
	fmt::fprintln(logger.handle, ""): void;
};

fn log_printfln(logger: *log::logger, fmt: str, fields: fmt::field...) void = {
	const logger = logger: *logfmtlogger;
	assert(logger.printfln == &log_printfln);
	
	const now = datetime::now();
	fmt::fprint(logger.handle, "ts="): void;
	datetime::format(logger.handle, datetime::RFC3339, &now): void;
	fmt::fprint(logger.handle, " "): void;

	for (let i = 0z; i < len(fields); i+= 1) {
		if (i % 2 == 0) {
			fmt::fprintf(logger.handle, "", fields[i]): void;
			fmt::fprint(logger.handle, "="): void;
		} else {
			fmt::fprintf(logger.handle, "", fields[i]): void;
			fmt::fprint(logger.handle, " "): void;
		};
	};
	fmt::fprintln(logger.handle, ""): void;
};