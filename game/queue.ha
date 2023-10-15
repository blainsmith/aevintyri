use fmt;

export type messageQueue = struct {
	arrsize: int,
    backingArr: []str,
};

export fn newqueue() *messageQueue = {
    let q = alloc(messageQueue {
		arrsize = 0,
		...
	});

	return q;
};

export fn queueadd(q: *messageQueue, m: str) void = {
    append(q.backingArr, m);
    q.arrsize = q.arrsize + 1;
};

export fn queueremove(q: *messageQueue) (str | void) = {
    if (q.arrsize > 0 ){
        let s = q.backingArr[0];
        delete(q.backingArr[0]);
        q.arrsize = q.arrsize - 1;
        return s;
        
    } else {
        return void;
    };
};

export fn queuelook(q: *messageQueue, i: int) str = {
    return q.backingArr[i];
};

export fn queueprint(q: *messageQueue) void = {
    fmt::println("---- start print ----")!;
    for (let i = 0z; i < len(q.backingArr); i += 1) {
            fmt::println(i)!;
			fmt::println(q.backingArr[i])!;
        };
    fmt::println("---- end print ----")!;
};

export fn queuegetsize(q: *messageQueue) int = {
    return q.arrsize;
};