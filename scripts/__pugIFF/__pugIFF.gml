
// replace this with your trace function.
#macro pIFF_trace trace

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

function pIFF_align(_b, _alignment, _pad) {
	var _a = _alignment - 1;
	var _p = is_undefined(_pad) ? 0 : _pad;
	while ((buffer_tell(_b) & _a) != 0) {
		if (buffer_read(_b, buffer_u8) != _p) {
			var _addr = string(ptr(buffer_tell(_b)));
			throw ("Caught invalid padding at address 0x" + _addr);
		}
	}
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
	var _textureId = ptr(buffer_read(_b, buffer_u16)); // *_get_texture return a pointer, so here we kinda match the things.
	
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
	
	// a little more hybrid
	var __fontSize = buffer_peek(_b, buffer_tell(_b), buffer_s32);
	var _fontSize = -1;
	
	// absurd! the size must be a float then.
	if (__fontSize < 0 || __fontSize > 1000) {
		pIFF_trace("Detected 2.3.1+ new font size");
		_fontSize = -(buffer_read(_b, buffer_f32));
	}
	else {
		// seems fine?
		_fontSize = __fontSize;
		// actually advance the offset
		buffer_read(_b, buffer_s32);
	}
	
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

function pIFF_readItemSPRTNormal(_b, _size, _id, _w, _h) {
	// TPAG entries list
	var _count = buffer_read(_b, buffer_u32);
	var _tpageAddresses = array_create(_count);
	for (var _i = 0; _i < _count; _i++) {
		_tpageAddresses[_i] = buffer_read(_b, buffer_u32);	
	}
	
	// masks list
	var __maskDataLength = (_w + 7) / 8 * _h;
	var _maskcount = buffer_read(_b, buffer_u32); // can be 1, or equal to the amount of frames.
	var _masks = array_create(_maskcount);
	for (var _i = 0; _i < _maskcount; _i++) {
		_masks[_i] = {
			address: buffer_tell(_b),
			length: __maskDataLength
		};
		
		// I don't want to actually read the mask into the memory.
		buffer_seek(_b, buffer_seek_relative, __maskDataLength);
	}
	
	return [ _tpageAddresses, _masks ];
}

function pIFF_readItemSPRTSpineEntry(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _width = buffer_read(_b, buffer_s32);
	var _height = buffer_read(_b, buffer_s32);
	var _pngLength = buffer_read(_b, buffer_u32);
	var _pngAddress = buffer_tell(_b);
	
	// again, don't wanna read the whole PNG into memory.
	buffer_seek(_b, buffer_seek_relative, _pngLength);
	
	return {
		address: _address,
		width: _width,
		height: _height,
		png: {
			address: _pngAddress,
			length: _pngLength
		}
	};
}

function pIFF_readItemSPRTSpine(_b, _size, _id) {
	pIFF_align(_b, 4, 0);
	
	var _address = buffer_tell(_b);
	var _version = buffer_read(_b, buffer_s32);
	if (_version != 2) {
		throw "pugIFF only supports Spine sprites version 2, sorry!";	
	}
	
	var __jsonLen = buffer_read(_b, buffer_s32);
	var __atlasLen = buffer_read(_b, buffer_s32);
	var __texturesCount = buffer_read(_b, buffer_s32);
	
	// don't want to read the huge JSON/atlas files into memory
	// and why would you want to do it anyway?
	var _jsonAddr = buffer_tell(_b);
	buffer_seek(_b, buffer_seek_relative, __jsonLen);
	var _atlasAddr = buffer_tell(_b);
	buffer_seek(_b, buffer_seek_relative, __atlasLen);
	
	var _textures = array_create(__texturesCount);
	for (var _i = 0; _i < __texturesCount; _i++) {
		_textures[_i] = pIFF_readItemSPRTSpineEntry(_b, _size, _id);
	}
	
	return {
		address: _address,
		version: _version,
		json: {
			address: _jsonAddr,
			length: __jsonLen
		},
		atlas: {
			address: _atlasAddr,
			length: __atlasLen
		},
		textures: _textures
	};
}

enum PIFF_SPECIAL_SPRITE_TYPE {
	BITMAP = 0, // basically a duplicate of the GM:S 1.4 data
	SWF = 1, // not supported
	SPINE = 2 // not tested
};

function pIFF_readItemSPRT(_b, _size, _id) {
	var _address = buffer_tell(_b);
	var _name = pIFF_readString(_b);
	var _width = buffer_read(_b, buffer_s32);
	var _height = buffer_read(_b, buffer_s32);
	var _marginLeft = buffer_read(_b, buffer_s32);
	var _marginRight = buffer_read(_b, buffer_s32);
	var _marginBottom = buffer_read(_b, buffer_s32);
	var _marginTop = buffer_read(_b, buffer_s32);
	var _transparent = bool(buffer_read(_b, buffer_s32));
	var _smooth = bool(buffer_read(_b, buffer_s32));
	var _preload = bool(buffer_read(_b, buffer_s32));
	var _bboxMode = buffer_read(_b, buffer_s32);
	var _colMaskType = buffer_read(_b, buffer_s32);
	var _originX = buffer_read(_b, buffer_s32);
	var _originY = buffer_read(_b, buffer_s32);
	
	// do not advance the offset here, just peek.
	var __isSpecialSprite = buffer_peek(_b, buffer_tell(_b), buffer_s32);
	var _isSpecialSprite = bool(__isSpecialSprite == -1);
	
	var _tpageAddresses = undefined;
	var _masks = undefined;
	
	var _specialVersion = 0;
	var _specialType = -1;
	var _playbackSpeed = 0.0;
	var _playbackType = -1;
	var _spineData = undefined;
	var _swfData = undefined;
	var _sequenceAddress = undefined;
	var _nineSliceAddress = undefined;
	
	if (_isSpecialSprite) {
		// actually read the -1
		buffer_read(_b, buffer_s32);
		
		// uh oh, plz somebody hold my hand I'm scared.
		_specialVersion = buffer_read(_b, buffer_s32);
		_specialType = buffer_read(_b, buffer_s32);
		
		// technically we should only read this if on GMS2, but this library is GMS2.3+ so I don't care.
		_playbackSpeed = buffer_read(_b, buffer_f32);
		_playbackType = buffer_read(_b, buffer_s32);
		if (_specialVersion >= 2) { // GMS 2.3+
			// read sequence data:
			_sequenceAddress = buffer_read(_b, buffer_u32);
			if (_specialVersion >= 3) { // GMS 2.3.2+
				// read 9slice data:
				_nineSliceAddress = buffer_read(_b, buffer_u32);
			}
		}
		
		switch (_specialType) {
			case PIFF_SPECIAL_SPRITE_TYPE.BITMAP: {
				var __arr = pIFF_readItemSPRTNormal(_b, _size, _id, _width, _height);
				_tpageAddresses = __arr[0];
				_masks = __arr[1];
				break;	
			}
			
			case PIFF_SPECIAL_SPRITE_TYPE.SWF: {
				pIFF_trace("SWF sprite detected name=", _name, "they are not supported by pugIFF yet.");
				//_swfData = whatever;
				break;
			}
			
			case PIFF_SPECIAL_SPRITE_TYPE.SPINE: {
				_spineData = pIFF_readItemSPRTSpine(_b, _size, _id);
				break;
			}
		}
	}
	else {
		var __arr = pIFF_readItemSPRTNormal(_b, _size, _id, _width, _height);
		_tpageAddresses = __arr[0];
		_masks = __arr[1];
	}
	
	return {
		address: _address,
		name: _name,
		width: _width,
		height: _height,
		marginLeft: _marginLeft,
		marginRight: _marginRight,
		marginBottom: _marginBottom,
		marginTop: _marginTop,
		transparent: _transparent,
		smooth: _smooth,
		preload: _preload,
		bboxMode: _bboxMode,
		colMaskType: _colMaskType,
		originX: _originX,
		originY: _originY,
		isSpecialSprite: _isSpecialSprite,
		tpageAddresses: _tpageAddresses,
		masks: _masks,
		specialVersion: _specialVersion,
		spineData: _spineData,
		swfData: _swfData,
		sequenceAddress: _sequenceAddress,
		nineSliceAddress: _nineSliceAddress
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

function pIFF_SPRTHandler(_b, _size, _id) {
	pIFF_trace("Parsing chunk", pIFF_idToString(_id));
	var _start = buffer_tell(_b);
	var _result = { chunkSize: _size, chunkStart: _start, chunkId: _id, items: pIFF_listHandler(_b, _size, _id, pIFF_readItemSPRT, true) };
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
			
			case PIFF_HEADER.SPRT: {
				_result.SPRT = pIFF_SPRTHandler(_b, _size, _hdr);	
			}
		}
	}
	
	return _result;
}