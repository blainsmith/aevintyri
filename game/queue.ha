use fmt;
use log;
use strings;

export type messageQueue = struct {
	backingArr: []str,
};

export fn newqueue() *messageQueue = {
	return alloc(messageQueue { ...});
};

export fn queueadd(q: *messageQueue, m: str) void = {
    append(q.backingArr, strings::dup(m));
};

export fn queueremove(q: *messageQueue) (str | void) = {
	if (len(q.backingArr) <= 0) {
		return void;
	};

	let msg = strings::dup(q.backingArr[0]);
	delete(q.backingArr[0]);

	return msg;
};

export fn queuelook(q: *messageQueue, i: int) str = {
    return strings::dup(q.backingArr[i]);
};

export fn queueprint(q: *messageQueue) void = {
    fmt::println("---- start print ----")!;
    for (let i = 0z; i < len(q.backingArr); i += 1) {
            fmt::println(i)!;
			fmt::println(q.backingArr[i])!;
        };
    fmt::println("---- end print ----")!;
};

export fn queuegetsize(q: *messageQueue) size = {
    return len(q.backingArr);
};

export fn queueprintall(q: *messageQueue) void = {
	log::println("queue size", len(q.backingArr));
	for (let i = 0z; i < len(q.backingArr); i += 1) {
		log::println(i, q.backingArr[i]);
	};
	log::println("");
};