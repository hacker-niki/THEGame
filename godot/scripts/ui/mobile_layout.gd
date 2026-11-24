extends RefCounted

# Reflow the shared screens into phone-sized controls, respecting display cutouts.
# The same buttons retain their keyboard focus, signals and accessibility text.
static func arrange(ui, safe: Rect2, portrait: bool) -> void:
	var inset := 16.0
	var area := safe.grow(-inset)
	var labels: Array[Label] = []
	for item in ui._stage.get_children():
		if item is Label:
			labels.append(item)
		elif item is ColorRect or item is Polygon2D:
			item.hide()
	for button in ui._stage_buttons:
		button.add_theme_font_size_override("font_size", 16 if button.variant == "link" else 18)
		button.clip_text = true
	if ui._mode in ["countdown","running"]:
		_hud(ui, area, portrait, labels)
	elif ui._mode == "menu" and ui._page == "home":
		_home(ui, area, portrait, labels)
	else:
		_page(ui, area, portrait, labels)


static func _home(ui, area: Rect2, portrait: bool, labels: Array[Label]) -> void:
	var x := area.position.x
	var buttons_x := x if portrait else x + area.size.x * 0.52
	var buttons_w := area.size.x if portrait else area.end.x - buttons_x
	var y := area.end.y - 278.0 if portrait else area.position.y + maxf(4.0, (area.size.y - 275.0) / 2.0)
	var title_y := y - 185.0 if portrait else area.position.y + maxf(8.0, (area.size.y - 238.0) / 2.0)
	var col := area.size.x if portrait else area.size.x * 0.48
	_text(labels[0], Rect2(x, title_y, col, 53), 53)
	_text(labels[1], Rect2(x - 2, title_y + 43, col, 94), 91)
	_text(labels[2], Rect2(x, title_y + 132, col, 48), 17, true)
	for i in range(3, labels.size()):
		labels[i].hide()
	for i in 4:
		_place(ui._stage_buttons[i], Rect2(buttons_x, y + i * 56, buttons_w, 49))
	var half := buttons_w * 0.5
	for i in 2:
		_place(ui._stage_buttons[4 + i], Rect2(buttons_x + i * half, y + 230, half - 8, 46))


static func _page(ui, area: Rect2, portrait: bool, labels: Array[Label]) -> void:
	var left := area.position.x
	var y := area.position.y + 5.0
	var col_w := area.size.x if portrait else area.size.x * 0.45
	var right := left if portrait else left + area.size.x * 0.49
	var form_w := area.size.x if portrait else area.end.x - right
	var body: Array[Label] = []
	var options: Array[Button] = []
	for b in ui._stage_buttons:
		if b.get_meta("ui_key") == "back":
			_place(b, Rect2(left, y, 105, 46))
			y += 50
		else:
			options.append(b)
	for label in labels:
		match str(label.get_meta("role", "")):
			"kicker":
				_text(label, Rect2(left, y, col_w, 20), 12)
				y += 23
			"title":
				var font_size := 32 if label.text.length() >= 15 else 39
				_text(label, Rect2(left - 1, y, col_w + 2, 52), font_size)
				y += 62
			_:
				body.append(label)
	if ui._mode == "menu" and ui._page == "tracks":
		_tracks(ui, Rect2(right, y if portrait else area.position.y + 3, form_w, area.size.y), portrait, options, body)
		return
	if ui._mode in ["crashed", "complete"] and body.size() >= 5:
		_text(body[0], Rect2(left,y,col_w,53),17,true)
		y += 67
		for i in 2:
			var cell := col_w * 0.5
			_text(body[1 + i * 2],Rect2(left + cell*i, y, cell-5, 22), 12)
			_text(body[2 + i * 2],Rect2(left + cell*i, y + 23, cell-5, 36), 27)
		y += 74
	else:
		for label in body:
			var large := label.get_theme_font_size("font_size") >= 32
			var small := label.get_theme_font_size("font_size") <= 17
			var sz := 31 if large else (14 if small else 17)
			var line_height := int(sz * 1.4)
			var text_width := label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz).x
			var rows := clampi(ceili(text_width / maxf(col_w-20,1)), 1, 4)
			var h := maxi(23, rows * line_height + 5)
			_text(label, Rect2(left,y,col_w,h), sz, true)
			y += h + 6
	var form_y := y + 12.0 if portrait else area.position.y + maxf(4.0, (area.size.y - options.size()*56.0)/2.0)
	for b in options:
		_place(b, Rect2(right, form_y, form_w, 49))
		form_y += 56
	if is_instance_valid(ui._driving_hint):
		ui._driving_hint.hide()
	# The desktop pause controls are a standalone group; show touch input names here.
	if ui._mode == "paused":
		for node in ui._stage.get_children():
			if node.get_class() == "Control":
				node.hide()
		var help := "Управляй стрелками" if ui._info.get("music",false) else "Стрелки — руль, кнопка справа — тормоз"
		var tip: Label = ui._label(help, Rect2(left, (form_y+5.0 if portrait else y+7.0), col_w, 46),ui.BODY,15,ui.MUTED,true)
		if not ui._touch_driving():
			tip.text = "A / D — руль" if ui._info.get("music",false) else "A / D — руль, пробел — тормоз"


static func _tracks(ui, form: Rect2, portrait: bool, buttons: Array[Button], body: Array[Label]) -> void:
	var half := (form.size.x - 6.0) * 0.5
	for i in 2:
		_place(buttons[i],Rect2(form.position.x + i*(half+6),form.position.y,half,46))
	var row_y := form.position.y + 54.0
	for i in 5:
		var b = buttons[i + 2]
		b.detail = b.detail if "%" in b.detail else ""
		b.add_theme_font_size_override("font_size", 17)
		_place(b,Rect2(form.position.x,row_y,form.size.x,46))
		row_y += 52
	if not body.is_empty():
		if portrait:
			_text(body[0],Rect2(form.position.x,row_y+4,form.size.x,24),15)
		else:
			var left: float = ui._mobile_bounds.position.x + 16
			_text(body[0],Rect2(left,ui._mobile_bounds.position.y+170,form.position.x - left - 14,26),15)


static func _hud(ui, area: Rect2, portrait: bool, labels: Array[Label]) -> void:
	var left := area.position.x
	var top := area.position.y
	var width := area.size.x
	var field := width - 64 if portrait else width * 0.44
	_text(labels[0],Rect2(left,top,field,17),12)
	_text(labels[1],Rect2(left,top+18,field,34),25)
	_place(ui._stage_buttons[0],Rect2(area.end.x-48,top,48,46))
	var x := left if portrait else left + width * 0.47
	var w := width if portrait else width * 0.39
	var y := top+58.0 if portrait else top
	_text(ui._hud_distance,Rect2(x,y,w*.73,24),16)
	_text(ui._hud_percent,Rect2(x+w*.74,y,w*.26,24),15)
	_place(ui._hud_bar,Rect2(x,y+29,w,4))
	if is_instance_valid(ui._countdown):
		var mid := area.get_center()
		_text(ui._countdown,Rect2(mid.x-75,mid.y-83,150,120),80)
	if is_instance_valid(ui._driving_hint):
		ui._driving_hint.position = Vector2(left, area.end.y - 67.0)
		ui._driving_hint.scale = Vector2(0.85,0.85)


static func _text(label: Label, bounds: Rect2, font_size: int, wrap := false) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(label, bounds)


static func _place(control: Control, bounds: Rect2) -> void:
	control.position = bounds.position
	control.size = bounds.size
