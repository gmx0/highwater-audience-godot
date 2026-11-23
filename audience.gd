extends Control
## A single clock drives the petitions, their deadlines, and all map movement.

const BEAT := 7.0
const SHIFT_END := 6
const MAP_ORIGIN := Vector2(28, 126)
const MAP_SIZE := Vector2(734, 448)
const INK := Color("#121e24")
const PAPER := Color("#e9ddbd")
const LIGHT := Color("#f6efda")
const SUBTLE := Color("#afc0c3")
const LAKE := Color("#376570")
const GOLD := Color("#fbd076")
const TEAL := Color("#b7edcc")
const RED := Color("#ffa597")
const TASKS := [
	{"name": "Captain Fen", "unit": "North Watch", "action": "Brace North Gate",
	 "letter": "The gate is buckling. Let my watch shore it up.",
	 "open": 0, "due": 4, "travel": 3, "color": GOLD,
	 "route": [Vector2(294, 263), Vector2(241, 220), Vector2(218, 150), Vector2(169, 99)]},
	{"name": "Captain Sable", "unit": "Ferry Guard", "action": "Secure Ferry Crossing",
	 "letter": "Families are waiting on the far bank. My guard can open a lane.",
	 "open": 1, "due": 6, "travel": 3, "color": TEAL,
	 "route": [Vector2(400, 297), Vector2(464, 265), Vector2(504, 205), Vector2(566, 170)]},
	{"name": "Iona", "unit": "Court courier", "action": "Warn Willow Hamlet",
	 "letter": "Optional: send one rider. Both squads keep their routes.",
	 "open": 1, "due": 5, "travel": 2, "color": Color("#e5b5ed"),
	 "route": [Vector2(322, 322), Vector2(271, 342), Vector2(189, 370), Vector2(128, 340)]},
]

var progress: float = 0.0
var beat: int = 0
var running := false
var orders: Array[Dictionary] = []
var records: Array[String] = []
var result := ""
var order_buttons: Array[Button] = []
var statuses: Array[Label] = []
var run_button: Button
var restart_button: Button
var headline: Label
var clock_label: Label
var log_label: Label

func _ready() -> void:
	var ui := Theme.new()
	ui.default_font_size = 18
	ui.set_color("font_color", "Button", LIGHT)
	ui.set_color("font_hover_color", "Button", LIGHT)
	ui.set_color("font_disabled_color", "Button", Color("#92a3a5"))
	ui.set_stylebox("normal", "Button", _style(Color("#314a50"), Color("#628087")))
	ui.set_stylebox("hover", "Button", _style(Color("#405e65"), GOLD))
	ui.set_stylebox("pressed", "Button", _style(Color("#476870"), GOLD))
	ui.set_stylebox("disabled", "Button", _style(Color("#24363b"), Color("#31484e")))
	ui.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, GOLD, 2))
	theme = ui
	_label("THE FLOOD WATCH  /  COUNTY OF REED", Vector2(28, 18), 15, GOLD)
	_label("Highwater Audience", Vector2(25, 40), 43, LIGHT)
	clock_label = _label("", Vector2(787, 24), 16, TEAL)
	run_button = _button("", Rect2(786, 61, 224, 41), _toggle)
	restart_button = _button("Restart  [R]", Rect2(1022, 61, 150, 41), _reset)
	_label("THE AUDIENCE", Vector2(789, 117), 16, GOLD)
	for i in TASKS.size():
		var y := 151 + i * 141
		_label(TASKS[i]["name"] + "  /  " + TASKS[i]["unit"], Vector2(803, y), 19, LIGHT)
		var letter := _label("", Vector2(803, y + 28), 16, SUBTLE)
		letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		letter.size = Vector2(349, 42)
		letter.name = "Letter%d" % i
		const KEYS := ["1", "2", "C"]
		order_buttons.append(_button("%s  [%s]" % [TASKS[i]["action"], KEYS[i]],
			Rect2(803, y + 73, 352, 35), _dispatch.bind(i)))
		statuses.append(_label("", Vector2(803, y + 111), 15, TASKS[i]["color"]))
	headline = _label("", Vector2(28, 592), 18, GOLD)
	log_label = _label("", Vector2(28, 626), 15, SUBTLE)
	var help := _label("Authorize petitions; squads travel on their own. Space runs or pauses the clock.", Vector2(789, 594), 16, SUBTLE)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size = Vector2(375, 70)
	_reset()

func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(5)
	return box

func _label(value: String, point: Vector2, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(value: String, bounds: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = bounds.position
	button.size = bounds.size
	button.pressed.connect(callback)
	add_child(button)
	return button

func _reset() -> void:
	progress = 0.0
	beat = 0
	running = false
	result = ""
	orders.clear()
	for _task in TASKS:
		orders.append({"state": "idle", "depart": -1.0, "eta": -1})
	records.clear()
	_note("Fen requests leave to deploy the North Watch.")
	_refresh()

func _note(value: String) -> void:
	records.append("%02d  /  %s" % [beat, value])

func _toggle() -> void:
	if result.is_empty():
		running = not running
		_refresh()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE: _toggle()
		KEY_1: _dispatch(0)
		KEY_2: _dispatch(1)
		KEY_C: _dispatch(2)
		KEY_R: _reset()
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not running:
		return
	progress = minf(progress + delta / BEAT, SHIFT_END)
	var next_beat := floori(progress)
	while running and beat < next_beat:
		beat += 1
		_resolve_beat()
	if not running:
		progress = float(beat)
	_refresh_clock()
	queue_redraw()

func _dispatch(index: int) -> void:
	if not result.is_empty():
		return
	var task: Dictionary = TASKS[index]
	var order: Dictionary = orders[index]
	if order.state != "idle" or beat < task.open:
		return
	order.state = "moving"
	order.depart = progress
	order.eta = beat + task.travel
	_note("%s dispatched to %s. ETA %02d%s." % [
		task.unit, _destination(index), order.eta, " (late)" if order.eta > task.due else ""])
	_refresh()

func _resolve_beat() -> void:
	if beat == 1:
		_note("Sable petitions for the ferry. Iona volunteers to warn the hamlet.")
	for i in TASKS.size():
		var task: Dictionary = TASKS[i]
		var order: Dictionary = orders[i]
		if order.state == "moving" and order.eta <= beat and beat <= task.due:
			order.state = "done"
			_note("%s: %s." % [_destination(i), ["gate braced", "crossing open", "warning delivered"][i]])
		elif (order.state == "idle" or order.state == "moving") and beat >= task.due:
			order.state = "missed"
			_note("%s: deadline missed." % _destination(i))
	if orders[0].state == "missed" or orders[1].state == "missed":
		result = "FLOOD LINE BROKEN  /  Restart to try another dispatch."
	elif beat >= SHIFT_END:
		result = "COUNTY SECURED  /  " + ("Willow was warned." if orders[2].state == "done" else "Both crossings held.")
	if not result.is_empty():
		running = false
	_refresh()

func _destination(index: int) -> String:
	return ["North Gate", "Ferry Crossing", "Willow Hamlet"][index]

func _refresh_clock() -> void:
	clock_label.text = "WATCH %02d / %02d    ·    %s" % [beat, SHIFT_END,
		"CLOSED" if not result.is_empty() else ("RUNNING" if running else "PAUSED")]

func _refresh() -> void:
	_refresh_clock()
	run_button.text = "Pause clock  [Space]" if running else "Run clock  [Space]"
	run_button.disabled = not result.is_empty()
	for i in TASKS.size():
		var task: Dictionary = TASKS[i]
		var order: Dictionary = orders[i]
		var available: bool = beat >= task.open
		var letter := get_node("Letter%d" % i) as Label
		letter.text = task.letter if available else "No petition yet."
		order_buttons[i].disabled = not available or order.state != "idle" or not result.is_empty()
		match order.state:
			"moving":
				statuses[i].text = "EN ROUTE  /  ETA %02d  ·  due %02d" % [order.eta, task.due]
				statuses[i].add_theme_color_override("font_color", RED if order.eta > task.due else task.color)
			"done":
				statuses[i].text = "COMPLETE  /  arrived %02d" % order.eta
				statuses[i].add_theme_color_override("font_color", task.color)
			"missed":
				statuses[i].text = "MISSED  /  due %02d" % task.due
				statuses[i].add_theme_color_override("font_color", RED)
			_:
				statuses[i].text = ("Due %02d  ·  predicted ETA %02d" % [task.due, beat + task.travel]) if available else "Expected at watch %02d" % task.open
				statuses[i].add_theme_color_override("font_color", RED if available and beat + task.travel > task.due else task.color)
	headline.text = result if not result.is_empty() else "DISPATCH LOG  /  Save North Gate and the Ferry Crossing"
	var latest: Array[String] = []
	for i in range(maxi(records.size() - 4, 0), records.size()):
		latest.append(records[i])
	log_label.text = "\n".join(latest)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1200, 740)), INK)
	draw_line(Vector2(28, 109), Vector2(1172, 109), Color("#4a6064"))
	draw_rect(Rect2(MAP_ORIGIN, MAP_SIZE), PAPER)
	for row in range(1, 14):
		draw_line(MAP_ORIGIN + Vector2(0, row * 32), MAP_ORIGIN + Vector2(734, row * 32), Color("#d9cbae"))
	for col in range(1, 23):
		draw_line(MAP_ORIGIN + Vector2(col * 32, 0), MAP_ORIGIN + Vector2(col * 32, 448), Color("#d9cbae"))
	var river := _points([Vector2(0, 154), Vector2(107, 150), Vector2(160, 190), Vector2(284, 171),
		Vector2(374, 204), Vector2(485, 171), Vector2(548, 213), Vector2(643, 230), Vector2(734, 189)])
	draw_polyline(river, Color("#65878a"), 54.0, true)
	draw_polyline(river, LAKE, 42.0, true)
	draw_polyline(river, Color("#9db6ac"), 1.0, true)
	_map_text(Vector2(22, 34), "REED COUNTY  /  STORM CHART", 15, INK)
	_map_text(Vector2(607, 37), "N ↑", 22, INK)
	_map_text(Vector2(32, 420), "● SQUAD      ◆ COURIER      × MISSED", 14, INK)
	_map_text(Vector2(286, 351), "CASTLE REED", 16, INK)
	draw_rect(Rect2(MAP_ORIGIN + Vector2(318, 274), Vector2(47, 33)), Color("#a08862"))
	for i in TASKS.size():
		_draw_route(i)
	for i in TASKS.size():
		var y := 144 + i * 141
		draw_rect(Rect2(786, y, 386, 138), Color("#1c2e35"))
		draw_rect(Rect2(786, y, 3, 138), TASKS[i]["color"])
	draw_rect(Rect2(28, 611, 734, 1), Color("#4a6064"))
	if running:
		draw_rect(Rect2(786, 52, 386.0 * progress / SHIFT_END, 3), GOLD)

func _points(path: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point: Vector2 in path:
		out.append(MAP_ORIGIN + point)
	return out

func _map_text(point: Vector2, value: String, size_px: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, MAP_ORIGIN + point, value, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size_px, color)

func _route_position(index: int) -> Vector2:
	var task: Dictionary = TASKS[index]
	var order: Dictionary = orders[index]
	var path: Array = task.route
	var phase := 0.0 if order.depart < 0 else clampf((minf(progress, float(task.due)) - order.depart) / (order.eta - order.depart), 0.0, 1.0)
	var segment := mini(floori(phase * 3), 2)
	var start: Vector2 = path[segment]
	return start.lerp(path[segment + 1], phase * 3 - segment)

func _draw_route(index: int) -> void:
	var task: Dictionary = TASKS[index]
	var order: Dictionary = orders[index]
	var route: Array = task.route
	var color: Color = task.color
	var dest: Vector2 = route.back()
	draw_polyline(_points(route), Color("#685a41"), 3.0, true)
	if order.state == "moving" or order.state == "done":
		draw_polyline(_points(route), color.darkened(0.27), 3.0, true)
	draw_circle(MAP_ORIGIN + dest, 14, INK, true, -1, true)
	if order.state == "missed":
		_map_text(dest + Vector2(-6, 6), "×", 20, RED)
	else:
		draw_arc(MAP_ORIGIN + dest, 9, 0, TAU, 28, color, 2, true)
	_map_text(dest + Vector2(-48, -23), _destination(index).to_upper(), 15, INK)
	var marker := MAP_ORIGIN + _route_position(index)
	if index == 2:
		draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -10), marker + Vector2(10, 0),
			marker + Vector2(0, 10), marker + Vector2(-10, 0)]), INK)
		draw_circle(marker, 4, color)
	else:
		draw_circle(marker, 10, INK, true, -1, true)
		draw_circle(marker, 5, color, true, -1, true)
