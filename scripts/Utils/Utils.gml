
// Feel free to replace all functions here with your own.


function trace() {
	var _out = string(argument[0]);
	for (var _i = 1; _i < argument_count; _i++) {
		_out += " " + string(argument[_i]);	
	}
	show_debug_message(_out);
	return _out;
}

function dump(_string) {
	var _b = buffer_create(string_byte_length(_string), buffer_fixed, 1);
	buffer_write(_b, buffer_text, _string);
	buffer_save(_b, "dump.txt");
	buffer_delete(_b);
}