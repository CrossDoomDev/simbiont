class_name SymbioteSkin
extends RefCounted
## Fixed corners and stretchable centers keep generated organic art responsive.
const PANEL: Texture2D = preload("res://assets/art/ui/panel.png")
const BUTTON: Texture2D = preload("res://assets/art/ui/button.png")
const BACKDROP: Texture2D = preload("res://assets/art/ui/backdrop.png")

static func panel(alpha: float = 1.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 22.0)
		box.set_content_margin(side, 24.0)
	box.modulate_color = Color(1, 1, 1, alpha)
	return box

static func button(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = BUTTON
	for side: int in [SIDE_LEFT, SIDE_RIGHT]:
		box.set_texture_margin(side, 54.0)
		box.set_content_margin(side, 26.0)
	for side: int in [SIDE_TOP, SIDE_BOTTOM]:
		box.set_texture_margin(side, 18.0)
		box.set_content_margin(side, 11.0)
	box.modulate_color = tint
	return box

static func fluid(color: Color, radius: int = 4) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box

static func apply(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", panel())
	for control: String in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", control, button())
		theme.set_stylebox("hover", control, button(Color(1.3, 1.12, 1.35)))
		theme.set_stylebox("pressed", control, button(Color(0.78, 0.68, 0.85)))
		theme.set_stylebox("disabled", control, button(Color(0.5, 0.45, 0.55)))
		var focus := fluid(Color(0.8, 0.4, 0.9, 0.12))
		focus.border_color = Color("d998e7")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", control, focus)
	var track := fluid(Color("37233d"))
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var fill := fluid(Color("9765b2"))
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var jewel := AtlasTexture.new()
	jewel.atlas = preload("res://assets/art/resources.png")
	jewel.region = Rect2(96,0,32,32)
	theme.set_icon("grabber", "HSlider", jewel)
	theme.set_icon("grabber_highlight", "HSlider", jewel)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		var scroll := fluid(Color("1d1224"))
		scroll.set_content_margin_all(4)
		var grabber := fluid(Color("a46bb9"))
		grabber.set_content_margin_all(4)
		theme.set_stylebox("scroll", bar, scroll)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber)
