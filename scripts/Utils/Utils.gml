


function trace() {
	var _out = string(argument[0]);
	for (var _i = 1; _i < argument_count; _i++) {
		_out += " " + string(argument[_i]);	
	}
	show_debug_message(_out);
	return _out;
}