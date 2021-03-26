
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