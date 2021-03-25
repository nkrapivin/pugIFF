
// replace this with your trace function.
#macro pIFF_trace trace

function pIFF_getIFFSuffix() {
	switch (os_type) {
		case os_android:
			return ".droid";
		case os_macosx:
		case os_ios:
			return ".ios";
		case os_linux:
			return ".unx";
		default:
			return ".win";
	}
}

function pIFF_getIFFPrefix() {
	switch (os_type) {
		case os_ps4:
		case os_psvita:
		case os_switch:
		case os_linux:
		case os_macosx:
			return "game";
		default:
			return "data";
	}
}

function pIFF_getIFFPath() {
	var _p1 = parameter_string(1);
	var _p2 = parameter_string(2);
    
	//Basic "are we running from IDE" check
	if (string_count(game_project_name + pIFF_getIFFSuffix(), _p2) > 0) {
		return _p2;	
	}
    
	//Sometimes game_project_name will replace hyphens with underscores when running under VM
	//Let's try to find out if that's happened
	//This trick only works on Windows I think...?
	if ((_p1 == "-game") && (os_type == os_windows)) {
		var _found_project_name = string_delete(_p2, 1, 3);
		_found_project_name = string_copy(_found_project_name, 1, string_length(game_project_name));
        
		if (string_count(_found_project_name + pIFF_getIFFSuffix(), _p2) > 0) {
			return _p2;
		}
	}
	
	return pIFF_getIFFPrefix() + pIFF_getIFFSuffix();
}

function pIFF_readString(_b) {
	var _addr = buffer_read(_b, buffer_u32);
	var _old = buffer_tell(_b);
	
	buffer_seek(_b, buffer_seek_start, _addr - 4);
	var _len = buffer_read(_b, buffer_u32);
	var _result = buffer_read(_b, buffer_string);
	
	if (string_length(_result) != _len) {
		pIFF_trace("Warning: misaligned/malformed string at address", ptr(_addr));	
	}
	
	buffer_seek(_b, buffer_seek_start, _old);
	
	return _result;
}

function pIFF_idToString(_id) {
	var _c1 = chr(_id & 0xFF);
	var _c2 = chr((_id >> 8) & 0xFF);
	var _c3 = chr((_id >> 16) & 0xFF);
	var _c4 = chr((_id >> 24) & 0xFF);
	var _name = _c1 + _c2 + _c3 + _c4;
	return _name;
}

function pIFF_dummyHandler(_b, _size, _id) {
	pIFF_trace("Parsing chunk", pIFF_idToString(_id));
	var _start = buffer_tell(_b);
	var _result = { chunkSize: _size, chunkStart: _start, chunkId: _id };
	
	// do nothing, literally skip over the whole chunk
	buffer_seek(_b, buffer_seek_relative, _size);
	
	return _result;
}

function pIFF_listHandler(_b, _size, _id, _handler, _skip) {
	// generic GameMaker List chunk
	/*  u32 count
	 *  repeat (count)
	 *      u32 pointer to item
	 *  u8 4byte aligned padding
	 */
	var _start = buffer_tell(_b);
	var _len = buffer_read(_b, buffer_u32);
	var _items = array_create(_len);
	for (var _i = 0; _i < _len; _i++) {
		var _itemaddr = buffer_read(_b, buffer_u32);
		var _itemold = buffer_tell(_b);
		
		buffer_seek(_b, buffer_seek_start, _itemaddr);
		_items[_i] = _handler(_b, _size, _id, true);
		buffer_seek(_b, buffer_seek_start, _itemold);
	}
	
	if (_skip) {
		// skip the remaining data which are the objects themselves
		var _rem = buffer_tell(_b) - _start;
		buffer_seek(_b, buffer_seek_relative, _size - _rem);
	}
	
	return _items;
}

function pIFF_readItemTPAG(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _sourceX = buffer_read(_b, buffer_u16);
	var _sourceY = buffer_read(_b, buffer_u16);
	var _sourceW = buffer_read(_b, buffer_u16);
	var _sourceH = buffer_read(_b, buffer_u16);
	var _targetX = buffer_read(_b, buffer_u16);
	var _targetY = buffer_read(_b, buffer_u16);
	var _targetW = buffer_read(_b, buffer_u16);
	var _targetH = buffer_read(_b, buffer_u16);
	var _boundingW = buffer_read(_b, buffer_u16);
	var _boundingH = buffer_read(_b, buffer_u16);
	var _textureId = buffer_read(_b, buffer_u16);
	
	return {
		address: _address,
		sourceX: _sourceX,
		sourceY: _sourceY,
		sourceW: _sourceW,
		sourceH: _sourceH,
		targetX: _targetX,
		targetY: _targetY,
		targetW: _targetW,
		targetH: _targetH,
		boundingW: _boundingW,
		boundingH: _boundingH,
		textureId: _textureId
	};
}

function pIFF_readItemFontGlyphKerning(_b, _size, _id) {
	var _kerningCount = buffer_read(_b, buffer_u16);
	var _kerningPairs = array_create(_kerningCount);
	for (var _i = 0; _i < _kerningCount; _i++) {
		var _address = buffer_tell(_b);
		var _kOther = buffer_read(_b, buffer_s16);
		var _kAmount = buffer_read(_b, buffer_s16);
		_kerningPairs[_i] = {
			address: _address,
			kOther: _kOther,
			kAmount: _kAmount
		};
	}
	
	return _kerningPairs;
}

function pIFF_readItemFONTGlyph(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _character = buffer_read(_b, buffer_u16);
	var _sourceX = buffer_read(_b, buffer_u16);
	var _sourceY = buffer_read(_b, buffer_u16);
	var _sourceWidth = buffer_read(_b, buffer_u16);
	var _sourceHeight = buffer_read(_b, buffer_u16);
	var _shift = buffer_read(_b, buffer_s16);
	var _offset = buffer_read(_b, buffer_s16);
	var _kerningPairs = pIFF_readItemFontGlyphKerning(_b, _size, _id);
	
	return {
		address: _address,
		character: _character,
		sourceX: _sourceX,
		sourceY: _sourceY,
		sourceWidth: _sourceWidth,
		sourceHeight: _sourceHeight,
		shift: _shift,
		offset: _offset,
		kerningPairs: _kerningPairs
	};
}

function pIFF_readItemFONT(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _name = pIFF_readString(_b);
	var _faceName = pIFF_readString(_b);
	
	// IN PRE-GMS2.3 THE FONT SIZE WAS A POSITIVE INTEGER
	// IN GMS2.3 IT'S A NEGATIVE FLOAT (0f - actualSize)
	// WHY? NO IDEA
	// WHAT? NO IDEA
	// WHAT'S THE REASON? NO IDEA
	// PUG? YES!
	//var _fontSize = buffer_read(_b, buffer_s32);
	var _fontSize = -(buffer_read(_b, buffer_f32));
	
	// int32 0==false, 1==true bruh.
	var _bold = bool(buffer_read(_b, buffer_s32));
	var _italic = bool(buffer_read(_b, buffer_s32));
	
	// 16+8+8=sizeof(int) >:(
	var _rangeStart = buffer_read(_b, buffer_s16);
	var _charset = buffer_read(_b, buffer_u8); // remnant from GM5-8.1
	var _antialiasing = buffer_read(_b, buffer_u8); // 0,1,2,3
	
	var _rangeEnd = buffer_read(_b, buffer_s32);
	var _tpagAddress = buffer_read(_b, buffer_u32); // this is the ADDRESS, not an INDEX.
	var _scaleX = buffer_read(_b, buffer_f32);
	var _scaleY = buffer_read(_b, buffer_f32);
	
	// BYTECODE >= 17 ONLY!!!!!!!!!
	var _ascenderOffset = buffer_read(_b, buffer_s32);
	
	// weird I know
	var _glyphs = pIFF_listHandler(_b, _size, _id, pIFF_readItemFONTGlyph, false);
	
	return {
		address: _address,
		name: _name,
		faceName: _faceName,
		fontSize: _fontSize,
		bold: _bold,
		italic: _italic,
		rangeStart: _rangeStart,
		charset: _charset,
		antialiasing: _antialiasing,
		rangeEnd: _rangeEnd,
		tpagAddress: _tpagAddress,
		scaleX: _scaleX,
		scaleY: _scaleY,
		asecnderOffset: _ascenderOffset,
		glyphs: _glyphs
	};
}

function pIFF_readItemAGRP(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _name = pIFF_readString(_b);
	
	return {
		address: _address,
		name: _name
	};
}

function pIFF_TPAGHandler(_b, _size, _id) {
	pIFF_trace("Parsing chunk", pIFF_idToString(_id));
	var _start = buffer_tell(_b);
	var _result = { chunkSize: _size, chunkStart: _start, chunkId: _id, items: pIFF_listHandler(_b, _size, _id, pIFF_readItemTPAG, true) };
	return _result;
}

function pIFF_FONTHandler(_b, _size, _id) {
	pIFF_trace("Parsing chunk", pIFF_idToString(_id));
	var _start = buffer_tell(_b);
	var _result = { chunkSize: _size, chunkStart: _start, chunkId: _id, items: pIFF_listHandler(_b, _size, _id, pIFF_readItemFONT, true) };
	return _result;
}

function pIFF_AGRPHandler(_b, _size, _id) {
	pIFF_trace("Parsing chunk", pIFF_idToString(_id));
	var _start = buffer_tell(_b);
	var _result = { chunkSize: _size, chunkStart: _start, chunkId: _id, items: pIFF_listHandler(_b, _size, _id, pIFF_readItemAGRP, true) };
	return _result;
}

enum PIFF_HEADER {
	FORM = 0x4D524F46,
	GEN8 = 0x384E4547,
	OPTN = 0x4E54504F,
	LANG = 0x474E414C,
	EXTN = 0x4E545845,
	SOND = 0x444E4F53,
	AGRP = 0x50524741,
	SPRT = 0x54525053,
	BGND = 0x444E4742,
	PATH = 0x48544150,
	SCPT = 0x54504353,
	GLOB = 0x424F4C47,
	SHDR = 0x52444853,
	FONT = 0x544E4F46,
	TMLN = 0x4E4C4D54,
	OBJT = 0x544A424F,
	ACRV = 0x56524341,
	SEQN = 0x4E514553,
	TAGS = 0x53474154,
	ROOM = 0x4D4F4F52,
	DAFL = 0x4C464144,
	EMBI = 0x49424D45,
	TPAG = 0x47415054,
	TGIN = 0x4E494754,
	CODE = 0x45444F43,
	VARI = 0x49524156,
	FUNC = 0x434E5546,
	STRG = 0x47525453,
	TXTR = 0x52545854,
	AUDO = 0x4F445541,
	DBGI = 0x49474244,
	INST = 0x54534E49,
	LOCL = 0x4C434F4C,
	DFNC = 0x434E4644, // what the hell?
	GMEN = 0x4E454D47, // gml_pragma("AtGameEnd", @".............
	PSPS = 0x53505350, // ps3 only
	STAT = 0x54415453  // xbox one only
};


function pIFF_parse(_b) {
	var _result = { };
	var _FORM = buffer_read(_b, buffer_u32);
	if (_FORM != PIFF_HEADER.FORM) {
		throw ("This is not a valid IFF you big doofus! buffer=" + string(_b));	
	}
	
	var _FORMlen = buffer_read(_b, buffer_u32); // length of the remaining chunks, or filesize-8, I don't care.
	pIFF_trace("FORM chunk detected, it's size=", _FORMlen);
	
	if (_FORMlen != (buffer_get_size(_b) - 8)) {
		pIFF_trace("Invalid FORM length, do you have extra data after the end of the file?!");	
	}
	
	_FORMlen += 8; // I trust FORM's length more, yknow?
	while (buffer_tell(_b) < _FORMlen) {
		var _hdr = buffer_read(_b, buffer_u32);
		var _size = buffer_read(_b, buffer_u32);
		switch (_hdr) {
			default: {
				// I am too lazy, Juju told me he only needs tpage entries, you do the rest of the work.
				// Keep in mind that chunks change formats between GM versions sometimes, so you gotta parse GEN8 first.
				_result[$ pIFF_idToString(_hdr)] = pIFF_dummyHandler(_b, _size, _hdr);
				break;
			}
			
			case PIFF_HEADER.FONT: {
				_result.FONT = pIFF_FONTHandler(_b, _size, _hdr);
				break;
			}
			
			case PIFF_HEADER.TPAG: {
				_result.TPAG = pIFF_TPAGHandler(_b, _size, _hdr);
				break;
			}
			
			case PIFF_HEADER.AGRP: {
				_result.AGRP = pIFF_AGRPHandler(_b, _size, _hdr);
				break;
			}
		}
	}
	
	return _result;
}