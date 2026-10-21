extends SceneTree
## Check bundled font data, full Russian alphabets and explicit symbol fallbacks.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FONT_CHECK_FAILED: " + message)

func _missing(font: Font, text: String) -> String:
	var missing := ""
	for character: String in text:
		if not font.has_char(character.unicode_at(0)):
			missing += character
	return missing

func _run() -> void:
	var russian := "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя"
	for entry: Array in [["Exo2.ttf","Exo 2"],["RussoOne-Regular.ttf","Russo One"]]:
		var face: FontFile = load("res://assets/fonts/" + entry[0])
		check(face.get_font_name() == entry[1], "font is the intended original family: " + entry[1])
		var missing: String = _missing(face,russian)
		check(missing == "", entry[1] + " includes all Russian letters including Ё/ё; missing=" + missing)
		check(_missing(face,"ҐґЄєІіЇїЎў0123456789%+.,:—·…") == "", entry[1] + " also supports extended Cyrillic and common interface characters")
	for name: String in ["regular", "semibold", "display"]:
		var role: FontVariation = load("res://assets/fonts/" + name + ".tres")
		var supported := true
		for character: String in "●○✦→Ⅱ×":
			var available: bool = role.base_font.has_char(character.unicode_at(0))
			for fallback: Font in role.fallbacks:
				available = available or fallback.has_char(character.unicode_at(0))
			supported = supported and available
		check(supported, name + " has bundled fallbacks for game icons without system fonts")
	for name: String in ["Exo2", "RussoOne"]:
		var license_text := FileAccess.get_file_as_string("res://assets/fonts/licenses/" + name + "-OFL.txt")
		check(license_text.contains("SIL OPEN FONT LICENSE"), "bundled license for " + name)
	check(FileAccess.get_file_as_string("res://assets/fonts/licenses/DejaVu-LICENSE.txt").contains("Bitstream"), "bundled license for DejaVu symbol fallback")
	var body: Font = load("res://assets/fonts/regular.tres")
	check(body.get_height(20) <= 27.0, "symbol fallback does not inflate paragraph line height")
	print("FONT_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
