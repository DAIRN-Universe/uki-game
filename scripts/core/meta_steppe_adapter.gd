class_name MetaSteppeAdapter
extends Node
## Replaceable proposal boundary. Only the server knows Meta credentials.
const MAX_ATTEMPTS := 2
const PROXY_URLS := ["http://127.0.0.1:8787/steppe", "http://localhost:8787/steppe"]
var request_timeout_seconds := 65.0
var attempts_used := 0
var used_fallback := false

func propose(world_seed: int, proxy_url: String) -> Dictionary:
	attempts_used = 0
	used_fallback = false
	if proxy_url not in PROXY_URLS:
		push_warning("Meta proxy URL rejected; using offline steppe.")
		return _fallback(world_seed)
	for attempt in range(MAX_ATTEMPTS):
		attempts_used += 1
		var request := HTTPRequest.new()
		request.timeout = request_timeout_seconds
		request.body_size_limit = 65536
		add_child(request)
		var error := request.request(proxy_url, ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, JSON.stringify({"version": 1, "seed": world_seed, "attempt": attempt}))
		if error != OK:
			request.queue_free()
			push_warning("Meta request could not start (attempt %d)." % attempt)
			continue
		var response: Array = await request.request_completed
		request.queue_free()
		if response[0] != HTTPRequest.RESULT_SUCCESS or response[1] != 200:
			push_warning("Meta endpoint unavailable (attempt %d)." % attempt)
			continue
		var parser := JSON.new()
		if parser.parse(response[3].get_string_from_utf8()) != OK:
			push_warning("Meta proposal rejected: invalid JSON (attempt %d)." % attempt)
			continue
		var candidate: Variant = parser.data
		var errors := SteppeValidator.validate(candidate, world_seed)
		if errors.is_empty():
			return candidate
		# Only deterministic diagnostics, never remote bodies or credentials.
		push_warning("Meta proposal rejected (attempt %d): %s" % [attempt, str(errors)])
	return _fallback(world_seed)

func _fallback(world_seed: int) -> Dictionary:
	used_fallback = true
	return SteppeGenerator.generate(world_seed)
