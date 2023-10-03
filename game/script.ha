use io;
use strings; 
use game; 
use os; 
use fmt;
use fs;

const max_u8: u8 = 65535;

let fullMap: []*area;


export fn parseScript (path: str) []*area = {

    let script io::file = os::open(str)!;
    defer io::close(script);

    let buf: *[65535]u8 = alloc([0...]);
    defer free(buf);

    let script_size int = io::readAll(script, buf);
    // check if io::underread

    let script_str str = fromutf8(buf); 
    let area_tokenizer = strings::rtokenize(script_str, "area ");
    let area_token;
    let newArea *area;

    while (peek_token(&area_tokenizer) != void) { // check if void
        area_token = string::next_token(&area_tokenizer); // area "area_name {dialog "*******" "north"}"
        area_token = strings::trim(area_token);
        *area = createAreaStruct(area_token);
        addToMap(newArea);
    };
};

fn createAreaStruct (str: areaStr) *area = {
    let name = parseAreaName(strings::sub(areaStr, 0, strings::index("{")));
    let dialog = parseAreaDialog();
    // let adjacent = parseAdjacent; 
    let subarea = parseSubArea();
    let item = parseItem;
    let newArea = alloc(area {
        name = name;
        dialog = dialog;
        adjacent = adjacent;
        subarea = subarea;
        item = item;
    });
    return newArea;
};

fn parseAreaName(area_name: str) str = {
    // trim off quotes, spaces, and braces
    return area_name;
};

fn parseAreaDialog (dialog: str) str = {
    
};

fn parseSubArea (subarea: str) (str, str) {

};

fn parseItem (item: str) (str, str) {

};

 // fn parseAdjacent()

fn addToMap(newArea: *area) void = {

};