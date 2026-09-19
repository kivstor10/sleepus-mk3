local attackers = {
	"SLEDGE", "THATCHER", "ASH", "THERMITE", "TWITCH", "MONTAGNE",
	"GLAZ", "FUZE", "BLITZ", "IQ", "BUCK", "BLACKBEARD", "CAPITAO",
	"HIBANA", "JACKAL", "YING", "ZOFIA", "DOKKAEBI", "LION", "FINKA",
	"MAVERICK", "NOMAD", "GRIDLOCK", "NOKK", "AMARU", "KALI", "IANA",
	"ACE", "ZERO", "FLORES", "OSA", "SENS", "GRIM", "STRIKER",
	"BRAVA", "RAM", "DEIMOS", "RAUORA", "SNAKE"
}

local defenders = {
	"SMOKE", "MUTE", "CASTLE", "PULSE", "DOC", "ROOK", "KAPKAN",
	"TACHANKA", "JAGER", "BANDIT", "FROST", "VALKYRIE", "CAVEIRA",
	"ECHO", "MIRA", "LESION", "ELA", "VIGIL", "MAESTRO", "ALIBI",
	"CLASH", "KAID", "MOZZIE", "WARDEN", "GOYO", "WAMAI", "ORYX",
	"MELUSI", "ARUNI", "THUNDERBIRD", "THORN", "AZAMI", "SOLIS",
	"FENRIR", "TUBARAO", "SENTRY", "SKOPOS", "DENARI", "NOOR"
}

local fields = {
	"SIDE", "OPERATOR", "WEAPON", "VERTICAL", "HORIZONTAL", "MOVEMENT",
	"DEAD ZONE", "RAPID FIRE", "FIRST BULLET", "FIRST BULLET %",
	"TEA BAG", "TEA MS", "SHAIKO LEAN", "READY"
}

local quick_select_buttons = {
	{controller.A, "qs_a", "A"}, {controller.B, "qs_b", "B"},
	{controller.X, "qs_x", "X"}, {controller.Y, "qs_y", "Y"},
	{controller.LB, "qs_lb", "LB"}, {controller.RB, "qs_rb", "RB"},
	{controller.DPAD_UP, "qs_du", "DPAD UP"},
	{controller.DPAD_DOWN, "qs_dd", "DPAD DOWN"},
	{controller.DPAD_LEFT, "qs_dl", "DPAD LEFT"},
	{controller.DPAD_RIGHT, "qs_dr", "DPAD RIGHT"},
	{controller.LS, "qs_ls", "LS"}, {controller.RS, "qs_rs", "RS"},
	{controller.LT, "qs_lt", "LT"}, {controller.RT, "qs_rt", "RT"}
}

local function quick_binding_key(side, button)
	return "qs" .. side .. "_" .. button[2]:sub(4)
end

local quick_storage_migrated = false
for _, button in ipairs(quick_select_buttons) do
	local binding = storage.read(button[2])
	if type(binding) == "number" then
		local side = math.floor(binding / 100)
		local operator = binding % 100
		local operators = side == 1 and attackers or defenders
		if (side == 1 or side == 2) and operator >= 1 and operator <= #operators then
			storage.write(quick_binding_key(side, button), operator)
		end
		storage.write(button[2], nil)
		quick_storage_migrated = true
	end
end
if quick_storage_migrated then storage.commit() end

local function quick_binding_name(side, operator)
	for _, button in ipairs(quick_select_buttons) do
		if storage.read(quick_binding_key(side, button)) == operator then
			return button[3]
		end
	end
	return "NONE"
end

local state = {
	configuring = true,
	menu_level = 0,
	game = 1,
	config_action = 1,
	config_status = 0,
	quick_select_enabled = storage.read("quick_select") == true,
	sab_enabled = storage.read("sab_enabled") ~= false,
	quick_previous = {},
	quick_view_previous = false,
	quick_navigation = false,
	quick_chord_active = false,
	quick_consumed = false,
	quick_open_side = 0,
	quick_open_operator = 0,
	last_operator = {1, 1},
	field = 1,
	field_editing = false,
	side = 1,
	operator = 1,
	weapon = 1,
	vertical = 0,
	horizontal = 0,
	movement = 80,
	deadzone = 12,
	rapid_fire = false,
	first_bullet = false,
	first_bullet_percent = 100,
	tea_bag = false,
	tea_bag_ms = 30,
	shaiko_lean = false,
	shaiko_dir = 0,
	previous_device = {false, false, false, false},
	device_repeat_at = {0, 0, 0, 0},
	previous_y = false,
	y_pressed_at = 0,
	previous_down = false,
	down_pressed_at = 0,
	down_tap_release = false,
	previous_rt = false,
	first_bullet_until = 0,
	display_ready = false
}

local loadout_profiles = {{}, {}}

local function loadout_profile()
	local side_profiles = loadout_profiles[state.side]
	local operator_profiles = side_profiles[state.operator]
	if not operator_profiles then
		operator_profiles = {}
		side_profiles[state.operator] = operator_profiles
	end
	local profile = operator_profiles[state.weapon]
	if not profile then
		local vertical, horizontal, movement, deadzone, rapid_fire,
			first_bullet, first_bullet_percent =
			storage.read_loadout(state.side, state.operator, state.weapon)
		profile = vertical and {
			vertical = vertical, horizontal = horizontal,
			movement = movement, deadzone = deadzone,
			rapid_fire = rapid_fire, first_bullet = first_bullet,
			first_bullet_percent = first_bullet_percent
		} or {
			vertical = 0, horizontal = 0, movement = 80, deadzone = 12,
			rapid_fire = false, first_bullet = false,
			first_bullet_percent = 100
		}
		operator_profiles[state.weapon] = profile
	end
	return profile
end

local function save_loadout_profile()
	local profile = loadout_profile()
	profile.vertical = state.vertical
	profile.horizontal = state.horizontal
	profile.movement = state.movement
	profile.deadzone = state.deadzone
	profile.rapid_fire = state.rapid_fire
	profile.first_bullet = state.first_bullet
	profile.first_bullet_percent = state.first_bullet_percent
	storage.write_loadout(state.side, state.operator, state.weapon,
		state.vertical, state.horizontal, state.movement, state.deadzone,
		state.rapid_fire, state.first_bullet, state.first_bullet_percent)
end

local function load_loadout_profile()
	local profile = loadout_profile()
	state.vertical = profile.vertical
	state.horizontal = profile.horizontal
	state.movement = profile.movement
	state.deadzone = profile.deadzone
	state.rapid_fire = profile.rapid_fire
	state.first_bullet = profile.first_bullet
	state.first_bullet_percent = profile.first_bullet_percent
end

local rapid_fire_macro = {
	{btn = controller.RT, val = 100, wait = 20},
	{btn = controller.RT, val = 0,   wait = 20}
}

-- Tea bag: B press/release while d-pad DOWN held >=250ms (Veritas QT_TEA_BAG_LOL)
-- [1].wait and [2].wait updated from state.tea_bag_ms before each start
local tea_bag_steps = {
	{btn = controller.B, val = 100, wait = 30},
	{btn = controller.B, val = 0,   wait = 30},
}

-- Shaiko lean left (d-pad LEFT + ADS): RS first, then RS+LS simultaneously
-- (Veritas ShaikoLeanLeft combo: 90ms RS only, 100ms RS+LS, 300ms RS+LS)
local shaiko_lean_left_steps = {
	{duration_ms = 90,  values = {[controller.RS] = 100}},
	{duration_ms = 100, values = {[controller.RS] = 100, [controller.LS] = 100}},
	{duration_ms = 300, values = {[controller.RS] = 100, [controller.LS] = 100}},
}

-- Shaiko lean right (d-pad RIGHT + ADS): LS first, then LS+RS simultaneously
-- (Veritas ShaikoLeanRight combo: 90ms LS only, 100ms LS+RS, 300ms LS+RS)
local shaiko_lean_right_steps = {
	{duration_ms = 90,  values = {[controller.LS] = 100}},
	{duration_ms = 100, values = {[controller.LS] = 100, [controller.RS] = 100}},
	{duration_ms = 300, values = {[controller.LS] = 100, [controller.RS] = 100}},
}

local function clamp(value, minimum, maximum)
	if value < minimum then return minimum end
	if value > maximum then return maximum end
	return value
end

local function round(value)
	if value < 0 then return math.ceil(value - 0.5) end
	return math.floor(value + 0.5)
end

local function operator_list()
	if state.side == 1 then return attackers end
	return defenders
end

local function on_off(value)
	if value then return "ON" end
	return "OFF"
end

local function device_action(id, index, now)
	local down = device.get_val(id) == 100
	local previous = state.previous_device[index]
	state.previous_device[index] = down
	if not down then
		state.device_repeat_at[index] = 0
		return false, false
	end
	if not previous then
		state.device_repeat_at[index] = now + 350
		return true, false
	end
	if now >= state.device_repeat_at[index] then
		state.device_repeat_at[index] = now + 80
		return true, true
	end
	return false, false
end

local function y_tapped()
	local down = controller.get_val(controller.Y) > 0
	local now = controller.get_millis()
	if down and not state.previous_y then
		state.y_pressed_at = now
	end
	local tapped = not down and state.previous_y and
		(now - state.y_pressed_at) < 500
	state.previous_y = down
	return tapped
end

local function run_tea_bag()
	local down = controller.get_val(controller.DPAD_DOWN) > 0
	local now = controller.get_millis()
	if state.down_tap_release then
		controller.set_val(controller.DPAD_DOWN, 0)
		state.down_tap_release = false
	end
	if down then
		if not state.previous_down then
			state.down_pressed_at = now
		end
		controller.set_val(controller.DPAD_DOWN, 0)
		if now - state.down_pressed_at >= 250 and
			not controller.macro_running("tea_bag") then
			tea_bag_steps[1].wait = state.tea_bag_ms
			tea_bag_steps[2].wait = state.tea_bag_ms
			controller.start_macro("tea_bag", tea_bag_steps)
		end
	elseif state.previous_down then
		if now - state.down_pressed_at < 250 then
			controller.set_val(controller.DPAD_DOWN, 100)
			state.down_tap_release = true
		end
		if controller.macro_running("tea_bag") then
			controller.stop_macro("tea_bag")
		end
	end
	state.previous_down = down
end

local function field_value(field)
	field = field or state.field
	if field == 1  then return state.side == 1 and "ATTACKERS" or "DEFENDERS" end
	if field == 2  then return operator_list()[state.operator] end
	if field == 3  then return state.weapon == 1 and "PRIMARY" or "SECONDARY" end
	if field == 4  then return tostring(state.vertical) end
	if field == 5  then return tostring(state.horizontal) end
	if field == 6  then return tostring(state.movement) .. "%" end
	if field == 7  then return tostring(state.deadzone) end
	if field == 8  then return on_off(state.rapid_fire) end
	if field == 9  then return on_off(state.first_bullet) end
	if field == 10 then return tostring(state.first_bullet_percent) .. "%" end
	if field == 11 then return on_off(state.tea_bag) end
	if field == 12 then return tostring(state.tea_bag_ms) .. "MS" end
	if field == 13 then return on_off(state.shaiko_lean) end
	return "SAVE AND START"
end

local function draw_operator_selector()
	local operators = operator_list()
	local first = math.floor((state.operator - 1) / 4) * 4 + 1
	for index = first, math.min(first + 3, #operators) do
		local text = index == state.operator and
			">" .. operators[index] .. "<" or operators[index]
		local x = math.floor((128 - #text * 6) / 2)
		display.draw_text(math.max(0, x), (index - first) * 8, text)
	end
end

local function draw_simple_list(title, labels, selected, reserve_marker)
	display.draw_text(0, 0, title)
	for index, label in ipairs(labels) do
		local selected_label = index == selected
		if reserve_marker and selected_label then
			display.draw_text(0, index * 8, ">")
		end
		local text = selected_label and
			(reserve_marker and label .. "<" or ">" .. label .. "<") or label
		display.draw_text(reserve_marker and 6 or 0, index * 8, text)
	end
end

local function draw_config_menu()
	local labels = {
		"EXPORT", "IMPORT", "QUICK SELECT " .. on_off(state.quick_select_enabled),
		"SAB " .. on_off(state.sab_enabled), "RESET ALL PROFILES"
	}
	local first = math.floor((state.config_action - 1) / 3) * 3 + 1
	display.draw_text(0, 0, "CONFIG")
	for row = 0, 2 do
		local index = first + row
		local label = labels[index]
		if label then
			local selected = index == state.config_action
			if selected then display.draw_text(0, (row + 1) * 8, ">") end
			display.draw_text(6, (row + 1) * 8,
				selected and label .. "<" or label)
		end
	end
end

local function field_visible(field)
	if field == 10 then return state.first_bullet end
	if field == 12 then return state.tea_bag end
	return true
end

local function visible_config_fields()
	local visible = {}
	for field = 3, #fields do
		if field_visible(field) then visible[#visible + 1] = field end
	end
	return visible
end

local function draw_operator_config()
	local visible = visible_config_fields()
	local selected = 1
	for index, field in ipairs(visible) do
		if field == state.field then selected = index break end
	end
	local first = math.floor((selected - 1) / 3) * 3 + 1
	local header = (state.side == 1 and "ATT > " or "DEF > ") ..
		operator_list()[state.operator]
	local binding = quick_binding_name(state.side, state.operator)
	if binding ~= "NONE" then
		local binding_x = math.max(0, 128 - #binding * 6)
		local max_header_length = math.floor((binding_x - 6) / 6)
		if #header > max_header_length then
			header = header:sub(1, math.max(1, max_header_length - 1)) .. "."
		end
		display.draw_text(binding_x, 0, binding)
	end

	display.draw_text(0, 0, header)
	for row = 0, 2 do
		local field = visible[first + row]
		if field then
			local selected_field = field == state.field
			local value = field_value(field)
			local label = fields[field]
			local label_text = selected_field and not state.field_editing and
				label .. "<" or label
			local value_text = value
			if selected_field then
				if state.field_editing then
					value_text = ">" .. value .. "<"
				end
			end
			if selected_field and not state.field_editing then
				display.draw_text(0, (row + 1) * 8, ">")
			end
			display.draw_text(6, (row + 1) * 8, label_text)
			display.draw_text(math.max(0, 128 - #value_text * 6),
				(row + 1) * 8, value_text)
		end
	end
end

local function draw_ui()
	led.set(state.menu_level == 1 and state.weapon == 1)
	display.clear()
	if state.menu_level == 0 then
		draw_simple_list("SELECT GAME", {"R6", "RUST", "CONFIG"}, state.game, true)
	elseif state.menu_level == 2 then
		display.draw_text(0, 0, "RUST")
		display.draw_text(0, 8, "COMING SOON")
		display.draw_text(0, 16, "LEFT: BACK")
	elseif state.menu_level == 3 then
		if state.config_status == 0 then
			draw_config_menu()
		elseif state.config_status == 1 then
			display.draw_text(0, 0, "REMOVE CONTROLLER")
			display.draw_text(0, 8, "INSERT USB STICK")
			display.draw_text(0, 16,
				state.config_action == 1 and "EXPORT WAITING" or "IMPORT WAITING")
		elseif state.config_status == 2 then
			display.draw_text(0, 0, "USB CONFIG")
			display.draw_text(0, 8, "WORKING")
			display.draw_text(0, 16, "DO NOT REMOVE")
		elseif state.config_status == 3 then
			display.draw_text(0, 0, "CONFIG COMPLETE")
			display.draw_text(0, 8, "REMOVE USB STICK")
			display.draw_text(0, 16, "CONNECT CONTROLLER")
			display.draw_text(0, 24, "LEFT: BACK")
		elseif state.config_status == 5 then
			display.draw_text(0, 0, "RESET ALL PROFILES?")
			display.draw_text(0, 8, "UP: CONFIRM")
			display.draw_text(0, 16, "DOWN: CANCEL")
		else
			local config_errors = {
				"UNKNOWN ERROR", "CONFIG NOT READY", "USB NOT READY",
				"USB READ ERROR", "FORMAT FAT32", "MOUNT ERROR",
				"FILE OPEN ERROR", "FILE WRITE ERROR", "FILE SYNC ERROR",
				"FILE CLOSE ERROR", "FILE RENAME ERROR", "FILE READ ERROR",
				"INVALID CONFIG"
			}
			display.draw_text(0, 0, "CONFIG FAILED")
			display.draw_text(0, 8,
				config_errors[device.config_error() + 1] or "UNKNOWN ERROR")
			display.draw_text(0, 16, "CONNECT CONTROLLER")
			display.draw_text(0, 24, "LEFT: BACK")
		end
	elseif state.configuring then
		if state.field == 1 then
			draw_simple_list("R6 > SIDE", {"ATTACKERS", "DEFENDERS"}, state.side, true)
		elseif state.field == 2 then
			draw_operator_selector()
			return
		else
			draw_operator_config()
			return
		end
	else
		local operators = operator_list()
		display.draw_text(0, 0, operators[state.operator] .. " " ..
			(state.weapon == 1 and "PRIMARY" or "SECONDARY"))
		display.draw_text(0, 8, "V" .. state.vertical ..
			" H" .. state.horizontal .. " M" .. state.movement ..
			" DZ" .. state.deadzone)
		display.draw_text(0, 16,
			"RAPID-" .. on_off(state.rapid_fire))
		display.draw_text(0, 24,
			"BOUND: " .. quick_binding_name(state.side, state.operator))
	end
end

local function field_repeats()
	local field = state.field
	return field == 2 or (field >= 4 and field <= 7) or
		field == 10 or field == 12
end

local function field_is_toggle(field)
	return field == 8 or field == 9 or field == 11 or field == 13
end

local function move_field(direction)
	local field = state.field
	repeat
		field = field + direction
	until field < 1 or field > #fields or field_visible(field)
	state.field = clamp(field, 1, #fields)
end

local function edit_field(direction)
	local field = state.field
	if field == 1 then
		save_loadout_profile()
		state.last_operator[state.side] = state.operator
		state.side = state.side == 1 and 2 or 1
		state.operator = state.last_operator[state.side]
		state.weapon = 1
		load_loadout_profile()
	elseif field == 2 then
		save_loadout_profile()
		state.operator = clamp(state.operator + direction, 1, #operator_list())
		state.last_operator[state.side] = state.operator
		load_loadout_profile()
	elseif field == 3 then
		save_loadout_profile()
		state.weapon = state.weapon == 1 and 2 or 1
		load_loadout_profile()
	elseif field == 4 then
		state.vertical = clamp(state.vertical + direction, 0, 99)
		save_loadout_profile()
	elseif field == 5 then
		state.horizontal = clamp(state.horizontal + direction, -30, 30)
		save_loadout_profile()
	elseif field == 6 then
		state.movement = clamp(state.movement + direction, 0, 99)
		save_loadout_profile()
	elseif field == 7 then
		state.deadzone = clamp(state.deadzone + direction, 1, 30)
		save_loadout_profile()
	elseif field == 8 then
		state.rapid_fire = not state.rapid_fire
		save_loadout_profile()
	elseif field == 9 then
		state.first_bullet = not state.first_bullet
		save_loadout_profile()
	elseif field == 10 then
		state.first_bullet_percent = clamp(state.first_bullet_percent + direction, 0, 200)
	elseif field == 11 then
		state.tea_bag = not state.tea_bag
	elseif field == 12 then
		state.tea_bag_ms = clamp(state.tea_bag_ms + direction, 1, 50)
	elseif field == 13 then
		state.shaiko_lean = not state.shaiko_lean
	end
end

local function save_and_start()
	save_loadout_profile()
	storage.commit()
	state.configuring = false
	state.field_editing = false
	controller.cancel_macros()
	draw_ui()
end

local function quick_button_edge(id)
	local down = controller.get_val(id) > 0
	local pressed = down and not state.quick_previous[id]
	state.quick_previous[id] = down
	return pressed
end

local function quick_open_side(side)
	if state.menu_level == 1 then
		save_loadout_profile()
		state.last_operator[state.side] = state.operator
	end
	state.menu_level = 1
	state.configuring = true
	state.field = 2
	state.field_editing = false
	state.side = side
	state.operator = 1
	state.weapon = 1
	load_loadout_profile()
	draw_ui()
end

local function quick_open_binding(side, operator)
	local operators = side == 1 and attackers or defenders
	if (side ~= 1 and side ~= 2) or operator < 1 or operator > #operators then
		return false
	end
	state.quick_open_side = side
	state.quick_open_operator = operator
	return true
end

local function apply_quick_open_binding()
	local side = state.quick_open_side
	local operator = state.quick_open_operator
	if side == 0 or operator == 0 then return end
	state.quick_open_side = 0
	state.quick_open_operator = 0
	if state.menu_level == 1 then save_loadout_profile() end
	state.menu_level = 1
	state.configuring = false
	state.field_editing = false
	state.field = 3
	state.side = side
	state.operator = operator
	state.last_operator[side] = operator
	state.weapon = 1
	load_loadout_profile()
	controller.cancel_macros()
	draw_ui()
end

local function update_quick_select()
	local view_down = controller.get_val(controller.VIEW) > 0
	local view_pressed = view_down and not state.quick_view_previous
	local pressed_button
	state.quick_consumed = false

	for _, button in ipairs(quick_select_buttons) do
		if quick_button_edge(button[1]) and not pressed_button then
			pressed_button = button
		end
	end
	state.quick_view_previous = view_down

	if not state.quick_select_enabled or
		(state.menu_level ~= 0 and state.menu_level ~= 1) then
		state.quick_navigation = false
		state.quick_chord_active = false
		return
	end
	if view_pressed then
		state.quick_navigation = false
		state.quick_chord_active = false
	end
	if not view_down then
		state.quick_navigation = false
		state.quick_chord_active = false
		return
	end

	local on_operator_selector = state.menu_level == 1 and
		state.configuring and state.field == 2
	local on_operator_config = state.menu_level == 1 and
		state.configuring and state.field > 2
	if state.quick_chord_active then
		controller.set_val(controller.VIEW, 0)
		state.quick_consumed = true
		if not pressed_button then return end
		controller.set_val(pressed_button[1], 0)
		if on_operator_selector and state.quick_navigation then
			local operator = storage.read(
				quick_binding_key(state.side, pressed_button))
			if type(operator) == "number" then
				quick_open_binding(state.side, operator)
			end
		end
		return
	end

	if pressed_button and not state.quick_navigation and
		not on_operator_config and
		(pressed_button[1] == controller.X or
		 pressed_button[1] == controller.B) then
		controller.set_val(controller.VIEW, 0)
		controller.set_val(pressed_button[1], 0)
		state.quick_consumed = true
		state.quick_chord_active = true
		quick_open_side(pressed_button[1] == controller.X and 1 or 2)
		state.quick_navigation = true
		return
	end
	if not pressed_button then return end

	if on_operator_config and not state.quick_navigation then
		controller.set_val(controller.VIEW, 0)
		controller.set_val(pressed_button[1], 0)
		state.quick_consumed = true
		state.quick_chord_active = true
		for _, button in ipairs(quick_select_buttons) do
			if button[2] ~= pressed_button[2] and
				storage.read(quick_binding_key(state.side, button)) ==
					state.operator then
				storage.write(quick_binding_key(state.side, button), nil)
			end
		end
		storage.write(quick_binding_key(state.side, pressed_button),
			state.operator)
		storage.commit()
		draw_ui()
		return
	end
end

local function update_menu()
	local now = controller.get_millis()
	local previous = device_action(device.BTN_DOWN, 1, now)
	local next = device_action(device.BTN_UP, 2, now)
	local decrease, decrease_repeat =
		device_action(device.BTN_SELECT, 3, now)
	local increase, increase_repeat =
		device_action(device.BTN_BACK, 4, now)

	if state.menu_level == 0 then
		if decrease or increase then
			state.game = state.game + (increase and 1 or -1)
			if state.game < 1 then state.game = 3 end
			if state.game > 3 then state.game = 1 end
			draw_ui()
		elseif next then
			state.menu_level = state.game
			state.config_status = 0
			draw_ui()
		end
		return
	end

	if state.menu_level == 2 then
		if previous then
			state.menu_level = 0
			draw_ui()
		end
		return
	end

	if state.menu_level == 3 then
		local status = device.config_status()
		if state.config_status ~= 5 and status ~= state.config_status then
			state.config_status = status
			if status == 3 and state.config_action == 2 then
				loadout_profiles = {{}, {}}
				state.quick_select_enabled = storage.read("quick_select") == true
				state.sab_enabled = storage.read("sab_enabled") ~= false
				load_loadout_profile()
			end
			draw_ui()
		end
		if state.config_status == 0 then
			if decrease or increase then
				state.config_action = state.config_action + (increase and 1 or -1)
				if state.config_action < 1 then state.config_action = 5 end
				if state.config_action > 5 then state.config_action = 1 end
				draw_ui()
			elseif next then
				if state.config_action == 5 then
					state.config_status = 5
					draw_ui()
				elseif state.config_action == 4 then
					state.sab_enabled = not state.sab_enabled
					storage.write("sab_enabled", state.sab_enabled)
					storage.commit()
					draw_ui()
				elseif state.config_action == 3 then
					state.quick_select_enabled = not state.quick_select_enabled
					storage.write("quick_select", state.quick_select_enabled)
					storage.commit()
					draw_ui()
				elseif device.config_request(state.config_action) then
					state.config_status = 1
					draw_ui()
				end
			elseif previous then
				state.menu_level = 0
				draw_ui()
			end
		elseif state.config_status == 5 then
			if decrease then
				storage.reset_loadouts()
				for _, button in ipairs(quick_select_buttons) do
					storage.write(quick_binding_key(1, button), nil)
					storage.write(quick_binding_key(2, button), nil)
				end
				state.quick_select_enabled = false
				storage.write("quick_select", false)
				storage.commit()
				loadout_profiles = {{}, {}}
				load_loadout_profile()
				state.config_status = 0
				draw_ui()
			elseif increase then
				state.config_status = 0
				draw_ui()
			end
		elseif state.config_status == 1 and previous then
			device.config_reset()
			state.menu_level = 0
			state.config_status = 0
			draw_ui()
		elseif (state.config_status == 3 or state.config_status == 4) and previous then
			device.config_reset()
			state.menu_level = 0
			state.config_status = 0
			draw_ui()
		end
		return
	end

	if not state.configuring then
		if previous then
			controller.cancel_macros()
			state.configuring = true
			state.field = state.field >= 3 and state.field or 3
			state.field_editing = false
			state.shaiko_dir = 0
			draw_ui()
		elseif next then
			controller.cancel_macros()
			state.configuring = true
			state.field = 1
			state.field_editing = false
			state.shaiko_dir = 0
			draw_ui()
		end
		return
	end

	if device.get_val(device.BTN_UP) == 100 and
		device.get_val(device.BTN_DOWN) == 100 then
		save_and_start()
		return
	end

	if state.field == 1 then
		if decrease or increase then
			edit_field(increase and 1 or -1)
			draw_ui()
		elseif next then
			state.field = 2
			draw_ui()
		elseif previous then
			controller.cancel_macros()
			state.menu_level = 0
			draw_ui()
		end
		return
	end

	if state.field == 2 then
		if increase and (not increase_repeat or field_repeats()) then
			edit_field(1)
			draw_ui()
		elseif decrease and (not decrease_repeat or field_repeats()) then
			edit_field(-1)
			draw_ui()
		elseif next then
			state.field = 3
			state.field_editing = false
			draw_ui()
		elseif previous then
			state.field = 1
			draw_ui()
		end
		return
	end

	if state.field_editing then
		if decrease and (not decrease_repeat or field_repeats()) then
			edit_field(1)
			draw_ui()
		elseif increase and (not increase_repeat or field_repeats()) then
			edit_field(-1)
			draw_ui()
		elseif next or previous then
			state.field_editing = false
			draw_ui()
		end
	elseif decrease or increase then
		move_field(increase and 1 or -1)
		draw_ui()
	elseif next then
		if state.field == #fields then
			save_and_start()
		elseif field_is_toggle(state.field) then
			edit_field(1)
			draw_ui()
		else
			state.field_editing = true
			draw_ui()
		end
	elseif previous then
		state.field = 2
		state.field_editing = false
		draw_ui()
	end
end

local function offset_axis(id, amount)
	local current = controller.get_val(id)
	local value = amount * (100 - math.abs(current)) / 100 + current
	controller.set_val(id, round(clamp(value, -100, 100)))
end

local function apply_recoil()
	if controller.get_val(controller.LT) == 0 or
		controller.get_val(controller.RT) == 0 then return end
	local vertical_recoil = state.vertical
	if controller.get_millis() < state.first_bullet_until and
		state.first_bullet and state.vertical ~= 0 then
		local multiplier = 1 + state.first_bullet_percent / 100
		vertical_recoil = state.vertical * multiplier
	end

	local x = controller.get_val(controller.RX)
	local y = controller.get_val(controller.RY)
	local sab_x = state.sab_enabled and math.random(-1, 1) or 0
	local sab_y = state.sab_enabled and math.random(-1, 1) or 0
	local magnitude = math.sqrt(x * x + y * y)
	if magnitude <= state.deadzone then
		if state.horizontal ~= 0 or sab_x ~= 0 then
			offset_axis(controller.RX, state.horizontal + sab_x)
		end
		if vertical_recoil ~= 0 or sab_y ~= 0 then
			offset_axis(controller.RY, vertical_recoil + sab_y)
		end
		return
	end

	local fade = clamp((100 - magnitude) /
		(100 - state.deadzone), 0, 1)
	local scale = state.movement / 100 * fade * fade
	local vertical_scale = scale
	if y * vertical_recoil > 0 then
		vertical_scale = 1 - math.abs(y) / 100
	elseif y == 0 then
		vertical_scale = 1
	end
	vertical_scale = vertical_scale *
		(1 - (math.abs(x) / 100) ^ 4)
	if state.horizontal ~= 0 or sab_x ~= 0 then
		offset_axis(controller.RX, state.horizontal * scale + sab_x)
	end
	if vertical_recoil ~= 0 or sab_y ~= 0 then
		offset_axis(controller.RY, vertical_recoil * vertical_scale + sab_y)
	end
end

local function run_macro(name, enabled, held, steps)
	if enabled and held then
		if not controller.macro_running(name) then
			controller.start_macro(name, steps)
		end
	elseif controller.macro_running(name) then
		controller.stop_macro(name)
	end
end

local function run_gameplay()
	-- Weapon switch on short Y tap
	if y_tapped() then
		save_loadout_profile()
		state.weapon = state.weapon == 1 and 2 or 1
		load_loadout_profile()
		draw_ui()
	end

	local firing  = controller.get_val(controller.RT) > 0
	local lt_held = controller.get_val(controller.LT) > 0
	local now = controller.get_millis()
	if firing and not state.previous_rt then
		state.first_bullet_until = now + 60
	end
	state.previous_rt = firing

	run_macro("rapid_fire", state.rapid_fire,  firing, rapid_fire_macro)

	-- Short DOWN taps are emitted on release; holds run tea bag without forwarding DOWN.
	if state.tea_bag then
		run_tea_bag()
	end

	-- Shaiko lean: ADS plus d-pad runs an RS/LS burst and suppresses d-pad RIGHT
	-- (Veritas ShaikoLeanLeft / ShaikoLeanRight)
	if state.shaiko_lean and lt_held then
		local want_left = controller.get_val(controller.DPAD_LEFT) > 0
		local want_right = controller.get_val(controller.DPAD_RIGHT) > 0
		controller.set_val(controller.DPAD_RIGHT, 0)
		local want_dir   = want_left and 1 or (want_right and 2 or 0)
		if want_dir ~= 0 then
			if not controller.macro_running("shaiko_lean") then
				local steps = want_dir == 1 and shaiko_lean_left_steps
				                              or shaiko_lean_right_steps
				controller.start_macro("shaiko_lean", steps)
				state.shaiko_dir = want_dir
			elseif want_dir ~= state.shaiko_dir then
				controller.stop_macro("shaiko_lean")
				local steps = want_dir == 1 and shaiko_lean_left_steps
				                              or shaiko_lean_right_steps
				controller.start_macro("shaiko_lean", steps)
				state.shaiko_dir = want_dir
			end
		elseif controller.macro_running("shaiko_lean") then
			controller.stop_macro("shaiko_lean")
			state.shaiko_dir = 0
		end
	elseif controller.macro_running("shaiko_lean") then
		controller.stop_macro("shaiko_lean")
		state.shaiko_dir = 0
	end

	apply_recoil()
end

function on_input()
	apply_quick_open_binding()
	if not state.display_ready then
		state.display_ready = true
		draw_ui()
	end
	update_quick_select()
	update_menu()
	if state.menu_level == 1 and not state.quick_consumed then
		run_gameplay()
	end
end

function on_console_connected()
	state.menu_level = 0
	state.quick_open_side = 0
	state.quick_open_operator = 0
	state.display_ready = true
	draw_ui()
end
