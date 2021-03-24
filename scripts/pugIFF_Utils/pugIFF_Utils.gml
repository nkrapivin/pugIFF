
function pugIFF_h(_str) {
	var _b = buffer_create(4, buffer_fixed, 1);
	buffer_write(_b, buffer_u8, ord(string_char_at(_str, 1)));
	buffer_write(_b, buffer_u8, ord(string_char_at(_str, 2)));
	buffer_write(_b, buffer_u8, ord(string_char_at(_str, 3)));
	buffer_write(_b, buffer_u8, ord(string_char_at(_str, 4)));
	var _i = buffer_peek(_b, 0, buffer_u32);
	buffer_delete(_b);
	var _p = ptr(_i);
	var _s = string(_p);
	return _s;
}

function pugIFF_genEnum() {
	var _names = "FORM\nGEN8\nOPTN\nLANG\nEXTN\nSOND\nAGRP\nSPRT\nBGND\nPATH\nSCPT\nGLOB\nSHDR\nFONT\nTMLN\nOBJT\nACRV\nSEQN\nTAGS\nROOM\nDAFL\nEMBI\nTPAG\nTGIN\nCODE\nVARI\nFUNC\nSTRG\nTXTR\nAUDO\nSCPT\nDBGI\nINST\nLOCL\nDFNC\nSTRG\nGMEN\nPSPS\nSTAT\n";
	var _str = "enum PIFF_HEADER {\r\n";
	var _f = file_text_open_from_string(_names);
	while (!file_text_eof(_f)) {
		var _name = file_text_read_string(_f);
		file_text_readln(_f);
		_str += "\t" + _name + " = 0x" + pugIFF_h(_name) + ",\r\n";
	}
	_str += "};\r\n";
	clipboard_set_text(_str);
	
	trace("chunk enum gen ok!");
}

pugIFF_genEnum();