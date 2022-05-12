# hare-logfmt

A logfmt logger that can be used in [`log::setlogger(*logger) void`](https://docs.harelang.org/log#setlogger) in Hare.

## Usage

```hare
use logfmt;
use log;

export fn main() void = {
    let l = logfmt::new(os::stderr);

	log::setlogger(&l);

    log::println(&l, "request_uri", "/", "method", "POST", "user_id", 123);
    log::println(&l, "request_uri", "/sign-in", "method", "GET");
    log::println(&l, "request_uri", "/dashboard", "method", "GET", "user_id", 123);
};
```

**Output**

```console
ts=2022-05-12T09:36:27-0400 request_uri=/ method=POST user_id=123
ts=2022-05-12T09:42:27-0400 request_uri=/sign-in method=GET
ts=2022-05-12T09:52:10-0400 request_uri=/dashboard method=GET user_id=123
```

You can also run `haredoc` to read the module documentation.

```console
> haredoc
// Implements the log::logger for outputting logs in Logfmt format.
type logfmtlogger = struct {
        log::logger,
        handle: io::handle,
};

// creates a new instace of logfmtlogger to be use with [[log::setlogger]].
fn new(handle: io::handle) logfmtlogger;
```