/// @description Did we load it?

if (async_load[? "id"] == op) {
	if (async_load[? "status"]) {
		// yeah we totally have the data.
		if (buffer_get_size(IFF) > 8) {
			trace("got the file", buffer_get_size(IFF));
			var _before = get_timer();
			var _pugIFFStruct = pIFF_parse(IFF);
			var _after = get_timer();
			var _diff = _after - _before;
			trace("look mom I parsed the file in ", _diff, "microsecs, are you proud of me? I miss you. :(");
			trace("what:\n", json_stringify(_pugIFFStruct));
			
			// feel free to place a breakpoint here:
			buffer_delete(IFF);
		}
	}
}