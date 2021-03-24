/// @description Load our own .win in parallel.


IFF = buffer_create(1, buffer_grow, 1);
var _fname = pIFF_getIFFPath();
op = buffer_load_async(IFF, _fname, 0, -1);

trace("loading file", _fname);