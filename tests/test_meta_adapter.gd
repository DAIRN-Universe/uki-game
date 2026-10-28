extends SceneTree
# Local fake transport only; no AI or credentials used by this suite.
var listener := TCPServer.new()
var peers: Array[StreamPeerTCP] = []
var buffers: Array[String] = []
var replies: Array[String] = []
var requests := 0
var checks := 0
var failures := 0
var adapter: MetaSteppeAdapter
var valid: Dictionary

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _init() -> void:
	call_deferred("run")

func _process(_delta: float) -> bool:
	if listener.is_listening() and listener.is_connection_available():
		peers.append(listener.take_connection())
		buffers.append("")
	for i in range(peers.size() - 1, -1, -1):
		peers[i].poll()
		if peers[i].get_status() != StreamPeerTCP.STATUS_CONNECTED:
			peers.remove_at(i)
			buffers.remove_at(i)
			continue
		if peers[i].get_available_bytes() > 0:
			buffers[i] += peers[i].get_utf8_string(peers[i].get_available_bytes())
		if "\r\n\r\n" in buffers[i]:
			requests += 1
			var body: String = replies.pop_front() if not replies.is_empty() else "unavailable"
			if body == "hang":
				buffers[i] = ""
				continue
			var status := "503 Unavailable" if body == "unavailable" else "200 OK"
			peers[i].put_data(("HTTP/1.1 %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.to_utf8_buffer().size(), body]).to_utf8_buffer())
			# Keep the stream alive until the client consumes its response.
			buffers[i] = ""
	return false

func same_world(world: Dictionary) -> bool:
	return world.cells == valid.cells and SteppeRules.start(world) == SteppeRules.start(valid) and int(world.seed) == int(valid.seed)

func run() -> void:
	valid = SteppeGenerator.generate(42)
	adapter = MetaSteppeAdapter.new()
	root.add_child(adapter)
	var error := listener.listen(8787, "127.0.0.1")
	if error != OK:
		push_error("Cannot bind mock proxy: stop other services on port 8787; network permission required.")
		quit(1)
		return
	replies = [JSON.stringify(valid)]
	var world := await adapter.propose(42, MetaSteppeAdapter.PROXY_URLS[0])
	check(same_world(world) and not adapter.used_fallback and adapter.attempts_used == 1, "valid proposal accepted")
	replies = ["{}", JSON.stringify(valid)]
	world = await adapter.propose(42, MetaSteppeAdapter.PROXY_URLS[0])
	check(same_world(world) and not adapter.used_fallback and adapter.attempts_used == 2, "invalid proposal retried")
	var open_rim := valid.duplicate(true)
	open_rim.cells[0] = "steppe"
	for bad_body in [JSON.stringify(open_rim), "not JSON", "{}", "unavailable", JSON.stringify(SteppeGenerator.generate(7)), "x".repeat(66000), "hang"]:
		adapter.request_timeout_seconds = 0.15 if bad_body == "hang" else 25.0
		replies = [bad_body, bad_body]
		world = await adapter.propose(42, MetaSteppeAdapter.PROXY_URLS[0])
		check(same_world(world) and adapter.used_fallback and adapter.attempts_used == 2, "invalid/unavailable response falls back")
	var before := requests
	world = await adapter.propose(42, "https://unapproved.invalid/steppe")
	check(same_world(world) and adapter.used_fallback and requests == before, "unapproved URL never requested")
	listener.stop()
	for peer in peers:
		peer.disconnect_from_host()
	peers.clear()
	world = await adapter.propose(42, MetaSteppeAdapter.PROXY_URLS[0])
	check(same_world(world) and adapter.used_fallback, "disconnected endpoint falls back")
	adapter.queue_free()
	print("META ADAPTER: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
