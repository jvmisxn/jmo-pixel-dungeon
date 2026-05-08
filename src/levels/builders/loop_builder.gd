class_name LoopBuilder
extends Builder
## Graph-based room placement that creates a loop layout.
## Mirrors Shattered PD's LoopBuilder.java.
##
## The layout strategy:
## 1. Place entrance and exit rooms as anchor points
## 2. Build a main path of standard rooms between them
## 3. Create a loop by building a second path connecting back
## 4. Attach remaining rooms as branches off the main loop
## 5. Fill gaps with connection rooms (tunnels)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

## How many standard rooms on the main path (adjusted by depth).
var path_length: int = 5
## Rooms on the side branch / loop return path.
var branch_length: int = 3

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func build(rooms_list: Array) -> bool:
	if rooms_list.size() < 2:
		return false

	# Categorize rooms
	var entrance_room: Room = null
	var exit_room: Room = null
	var standard_rooms: Array[Room] = []
	var connection_rooms: Array[Room] = []
	var special_rooms: Array[Room] = []
	var secret_rooms: Array[Room] = []

	for r: Variant in rooms_list:
		var room: Room = r as Room
		match room.type:
			Room.Type.ENTRANCE:
				entrance_room = room
			Room.Type.EXIT:
				exit_room = room
			Room.Type.STANDARD:
				standard_rooms.append(room)
			Room.Type.CONNECTION:
				connection_rooms.append(room)
			Room.Type.SPECIAL:
				special_rooms.append(room)
			Room.Type.SECRET:
				secret_rooms.append(room)

	if entrance_room == null or exit_room == null:
		return false

	# Size all rooms
	for room: Variant in rooms_list:
		(room as Room).set_random_size()

	# --- Main loop construction ---
	# Split standard rooms into two paths: main and branch
	standard_rooms.shuffle()
	@warning_ignore("integer_division")
	var half: int = standard_rooms.size() / 2
	var main_path: Array[Room] = []
	var branch_path: Array[Room] = []
	for i: int in range(standard_rooms.size()):
		if i < half:
			main_path.append(standard_rooms[i])
		else:
			branch_path.append(standard_rooms[i])

	# Build the full loop order: entrance -> main_path -> exit -> branch_path -> (back to entrance)
	var loop: Array[Room] = []
	loop.append(entrance_room)
	loop.append_array(main_path)
	loop.append(exit_room)
	loop.append_array(branch_path)

	# Place rooms along the loop
	var placed: Array[Room] = []
	var success: bool = _place_loop(loop, placed)
	if not success:
		return false

	# Place special rooms branching off the loop
	for sroom: Room in special_rooms:
		if not _place_branch_room(sroom, placed):
			# If we can't place it, skip (non-critical)
			pass

	# Place secret rooms
	for sroom: Room in secret_rooms:
		if not _place_branch_room(sroom, placed):
			pass

	# Fill connections between adjacent rooms that need tunnels
	_place_connection_rooms(connection_rooms, loop, placed)

	return true

# ---------------------------------------------------------------------------
# Loop Placement
# ---------------------------------------------------------------------------

func _place_loop(loop: Array[Room], placed: Array[Room]) -> bool:
	if loop.is_empty():
		return false

	# Place the first room near the center of the map
	var first: Room = loop[0]
	@warning_ignore("integer_division")
	var cx: int = ConstantsData.WIDTH / 2 - first.width() / 2
	@warning_ignore("integer_division")
	var cy: int = ConstantsData.HEIGHT / 2 - first.height() / 2
	first.set_pos(cx, cy)

	if not first.in_bounds():
		first.set_pos(4, 4)

	placed.append(first)

	# Place each subsequent room adjacent to the previous one
	for i: int in range(1, loop.size()):
		var room: Room = loop[i]
		var prev: Room = loop[i - 1]
		var attempts: int = 0
		var room_placed: bool = false

		while attempts < 30 and not room_placed:
			room.set_random_size()
			room_placed = Builder.place_adjacent(room, prev, placed, 1)
			attempts += 1

		if not room_placed:
			# Try placing adjacent to any already-placed room
			var fallback_targets: Array[Room] = placed.duplicate()
			fallback_targets.shuffle()
			for target: Room in fallback_targets:
				room.set_random_size()
				if Builder.place_adjacent(room, target, placed, 1):
					room_placed = true
					# Connect to this target instead
					if not Builder.connect_adjacent(room, target):
						room.neighbors.append(target)
						target.neighbors.append(room)
					break

		if not room_placed:
			return false

		placed.append(room)

		# Connect sequential rooms
		if not Builder.connect_adjacent(room, prev):
			# Rooms aren't directly adjacent — they'll need a tunnel
			# Mark them as neighbors for tunnel building
			room.neighbors.append(prev)
			prev.neighbors.append(room)

	# Close the loop: connect last room back to first
	var last: Room = loop[loop.size() - 1]
	if not Builder.connect_adjacent(last, first):
		last.neighbors.append(first)
		first.neighbors.append(last)

	return true

# ---------------------------------------------------------------------------
# Branch Room Placement
# ---------------------------------------------------------------------------

func _place_branch_room(room: Room, placed: Array[Room]) -> bool:
	# Try attaching to random rooms on the loop
	var targets: Array[Room] = placed.duplicate()
	targets.shuffle()

	for target: Room in targets:
		var attempts: int = 0
		while attempts < 10:
			room.set_random_size()
			if Builder.place_adjacent(room, target, placed, 1):
				placed.append(room)
				if not Builder.connect_adjacent(room, target):
					# Rooms aren't directly adjacent (gap between them) —
					# mark as neighbors so a tunnel will be carved later
					room.neighbors.append(target)
					target.neighbors.append(room)
				return true
			attempts += 1

	return false

# ---------------------------------------------------------------------------
# Connection Room Placement
# ---------------------------------------------------------------------------

func _place_connection_rooms(conn_rooms: Array[Room], loop: Array[Room], placed: Array[Room]) -> void:
	# For each pair of rooms in the loop that are neighbors but not directly connected,
	# try to place a connection room between them
	var conn_idx: int = 0

	for i: int in range(loop.size()):
		var a: Room = loop[i]
		var b: Room = loop[(i + 1) % loop.size()]

		# If already connected with a door, skip
		if a.is_connected_to(b):
			continue

		# Try to place a connection room between them
		if conn_idx >= conn_rooms.size():
			continue

		var conn: Room = conn_rooms[conn_idx]

		# Try placing adjacent to room a
		for _attempt: int in range(15):
			conn.set_random_size()
			if Builder.place_adjacent(conn, a, placed, 1):
				placed.append(conn)
				# Connect conn to a
				if not Builder.connect_adjacent(conn, a):
					if not conn in a.neighbors:
						a.neighbors.append(conn)
					if not a in conn.neighbors:
						conn.neighbors.append(a)
				# Connect conn to b
				if not Builder.connect_adjacent(conn, b):
					if not conn in b.neighbors:
						b.neighbors.append(conn)
					if not b in conn.neighbors:
						conn.neighbors.append(b)
				conn_idx += 1
				break
