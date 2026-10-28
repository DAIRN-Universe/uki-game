# Issue #1 implementation and verification

Specification: [UKI-META-MVP-01](https://github.com/DAIRN-Universe/uki-game/issues/1), read on 2026-10-28, including its manifesto and README requirements. The repository initially contained `LICENSE` and an untracked canonical `MANIFESTO.md`; no game code or tests existed. Existing IDE files were left alone and excluded with `.gitignore`.

**Status: implemented for review; not human-accepted or merged.** Automated checks and a rendered-scene inspection provide the evidence below. Live Meta Muse Spark generation and deterministic acceptance were verified on 2026-10-29. Executable packaging and a human playthrough remain unverified. The former Llama endpoint returned HTTP 401; the human-approved Muse Spark migration subsequently produced a valid world.

## Implementation sequence

1. Added axial geometry and flat pointy-top rendering, then deterministic movement/flight state and player controls.
2. Added seeded geography and deterministic validation. Ran the initial core suite **before integrating Meta**: 2,342 checks passed across 64 generated seeds plus the default example, movement restrictions, river validation, and a complete gameplay-state traversal to victory.
3. Finished fog, camera, and victory presentation; verified the game scene and movement interpolation.
4. Replaced the offline proposal boundary with the optional Meta transport and separate credential-holding server. Added versioned JSON schemas, retry/fallback behavior, and mocked network tests.
5. Expanded regression coverage, documented setup/controls/architecture, preserved the canonical manifesto with its required link change, and added a repeatable check script and CI configuration.
6. Applied the subsequently approved closed boundary: all 60 boundary cells are mountain or sea, and only the two unreachable axial corners are excluded from victory. Updated generation, deterministic validation, shared victory rules, Meta context/schema documentation, and regression tests. The reveal radius remains one.

## Human-approved AI model change

The human explicitly approved replacing the original Issue #1 **Llama** model with **Meta Muse Spark** after the Llama endpoint rejected the supplied credential with HTTP 401. The proxy now calls `https://api.meta.ai/v1/chat/completions`, selects `muse-spark-1.3`, reads only `MODEL_API_KEY`, and parses `choices[0].message.content` according to the [official Meta protocol](https://dev.meta.ai/docs/protocols/chat-completions). Requests use a developer message, low reasoning effort, the model's default sampling, and strict JSON Schema structured output. Incomplete, refused, tool-call, or malformed replies are rejected before returning a proposal; the game still applies its complete deterministic validator.

This is an approved change to the original issue's named model, not a third-party AI integration. The fixed Meta-only host/model policy, credential separation, client protocol, geography/movement rules, and offline fallback remain in place. Safe failure responses/logs report only fixed diagnostic codes and numeric HTTP status, without exception text, tokens, headers, or remote response bodies. Existing proxy processes must be restarted to load the change. An initial live Muse map request hit the former 20-second timeout; an unauthenticated endpoint probe returned HTTP 401 in 0.8 seconds. The operational budgets were therefore raised to 60 seconds upstream and 65 seconds in the client; a subsequent authenticated Muse generation succeeded in 26.17 seconds and passed deterministic validation.

## Startup presentation

A subsequent human request adds a presentation sequence: **DAIRN PRESENT** fades in, holds, and fades out, followed by **UKI** and a **PLAY** button. The button supports mouse activation and focused keyboard activation (Enter/Space). Gameplay generation and optional Meta requests begin only after PLAY. Command-line seed arguments survive the scene change. The PLAY screen displays `© 2026 ANDREY SVIININYKH` and `Licensed under the MIT License` below the button. The title uses native Godot text and flat colors; no generated assets or new gameplay rules are introduced.

The project now opens `scenes/title.tscn`; `scenes/main.tscn` remains the gameplay scene and can be run directly for testing. The presentation script is `scripts/game/title.gd`, and regression checks are in `tests/test_title.gd`.

## Rule interpretations

Issue #1 fixes dimensions, terrain colors, maximum flight range, impassability, and the reveal-based victory goal. For details without an explicit value, the implementation chooses:

- One-hex reveal radius: the occupied hex plus six neighbors.
- Walking and landing on steppe only; rivers are crossed by flight.
- Straight center-to-center flight trajectories with conservative hex intersection; touching either side of a mountain/sea edge blocks flight.
- A subsequent explicit human decision requires every boundary cell to be mountain or sea. Reveal radius remains one. Only axial corners `(0,0)` and `(15,15)` are excluded from victory because their in-bounds neighbors all belong to the impassable rim. The other 254 cells, including the other two corners and visible rim terrain, remain required. These two excluded cells remain fogged; future visibility changes are deferred.
- Discovery is persistent within a session. There is no save/load feature.

The boundary and two-corner victory exception were explicitly approved by the human after the initial implementation. The approved palette and movement/reveal ranges are unchanged. Successful exploration displays the requested centered `Congratulation!!!` banner; it remains hidden until victory and does not block continued movement. No excluded gameplay or generated visual assets were added.

## Acceptance evidence

| Issue acceptance criterion | Implementation and verification |
| --- | --- |
| Valid seeded 16×16 steppe, reproducible | Generator retries candidates deterministically and validates before returning. Core tests cover seeds 0–63, 2026, -1, and signed 32-bit extremes; repeat generation, distinct example seeds, and the emergency fallback family member are checked. |
| Aligned pointy-top hexes, exact colors, visible borders | Geometry tests check 1,681 coordinate round trips, neighbor spacing, and exactly two shared vertices per shared edge. All six palette constants are checked. The displayed scene samples rendered centers against the palette; viewport inspected visually. Radius 36, width `sqrt(3)*36`, row spacing 54. |
| Smooth movement, valid selected flight, invalid flight rejected | Scene tests observe an intermediate interpolated position, final centers, selected range-three flight, and invalid-action rejection. Core tests cover all directions, range, bounds, landings, river crossings, mountain/sea blocking, edge ties, and trajectory symmetry. |
| Mountains/sea impassable; mountain-to-sea rivers | Shared action rules block these terrains for walking/landing/trajectories. Validator checks declared path continuity, no repeated cells, terrain coverage, and endpoints adjacent to mountain/sea. Mutated river cases are rejected. |
| Fog, scrolling camera, exploration victory | Initial discovery is local; scene checks interpolation and following camera. Core test explores and backtracks a spanning tree using only `ExplorationState.move_to`, revealing all 254 required cells and triggering victory while the two exempt corners remain fogged. HUD exposes no dimensions or percentage; unknown lattice fills the viewport. |
| Reject unsolvable geography | Validator performs BFS over actual legal flight destinations, unions actual reveal neighborhoods, and rejects incomplete coverage. A trapped-start regression fixture is rejected. |
| Runs without credentials/API | Offline scene/startup tests pass with no API configuration. Game state and rules have no AI dependency. Missing server, HTTP failures, invalid outputs, oversized bodies, and timeouts trigger deterministic fallback. |
| Meta-only AI calls | Server fixes Meta's endpoint and Muse Spark model, prevents redirects, and holds credentials outside the game. Mocked tests inspect outgoing URL/model/schema and verify redacted failures. Live Muse generation returned HTTP 200 and its world passed the game validator and a legal traversal to victory on 2026-10-29. |

## Executed checks

Environment: Linux x86_64, **Godot 4.7.2 stable** (`ed1daf0bf`), compatibility renderer. Godot was downloaded temporarily from the official release; no engine binary was added to this repository. The rendered test used Intel Mesa OpenGL 4.6. Python tests use the standard library.

| Check | Result |
| --- | --- |
| `GODOT_BIN=<Godot 4.7.2> tools/check.sh` | Pass; imports project, runs all suites and startup smoke check; rejects engine/parser errors even with a zero editor exit status. |
| `godot --headless --path . --editor --import` | Pass; global classes and scene import without script errors. |
| `godot --headless --path . --script tests/test_core.gd` | **7,797 checks, 0 failures**, including sealed boundaries across 64 seeds, rejection of steppe/river on each of the 60 boundary cells, impassable boundary movement checks, and proof that each of the 254 non-exempt cells is necessary for victory. |
| `godot --headless --path . --script tests/test_title.gd -- --seed=42` | **15 checks, 0 failures**: studio intro sequence, menu readiness, focused keyboard PLAY activation, scene transition, preserved seed, and initial gameplay discovery. |
| `godot --path . --audio-driver Dummy --script tests/test_title.gd -- --seed=42` | **17 checks, 0 failures**, including studio and menu viewport captures; both frames inspected visually. |
| `godot --headless --path . --script tests/test_game.gd` | **15 checks, 0 failures**. |
| `godot --path . --audio-driver Dummy --script tests/test_game.gd` | **17 checks, 0 failures**, including real viewport capture and exact rendered center colors. |
| `godot --headless --path . --script tests/test_meta_adapter.gd` | **11 checks, 0 failures**: valid acceptance, invalid-then-valid retry, open-boundary/malformed/schema/wrong-seed rejection, HTTP failure, oversized body, timeout, unapproved URL, disconnected endpoint. |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | **9 tests passed**: strict request boundary, no-key behavior, Muse completion parsing, fixed Meta routing/model/schema, rejection of incomplete/refused/malformed replies, isolation from the former key variable, malformed/oversized responses, redirect blocking, error redaction, and fixed diagnostic categories for missing keys, HTTP failures, network failures, and malformed responses. |
| `godot --headless --path . --quit-after 10` | Pass; no credentials required. |
| `godot --headless --path . --export-pack Linux /tmp/uki-game.zip` | Pass; 21 archive entries inspected. No server, tests, docs, tools, GitHub configuration, or `.env` entries included. This checks resource packaging, not an executable export. |
| Manifesto comparison | Exact canonical source content after only substituting its repository-specific `docs/PRE_EXISTING.md` target. |

The generator intentionally logs and retries candidates whose meandering river or projections make a cell unrevealable. Expected warnings also appear for deliberately invalid mock Meta responses. These are exercised rejection paths, not failed tests. In this sandbox, display and socket tests required broader execution access; redirected XDG paths kept engine data under `/tmp`.

The pixel test was corrected to include Godot's viewport stretch transform when sampling a resized window. It then passed; the actual palette values were unchanged. `.github/workflows/checks.yml` configures the offline suite with a checksum-pinned official engine archive; the remote GitHub Actions workflow has not been executed during this task.

## Live Muse verification — 2026-10-29

A real request through the user's running local proxy returned **HTTP 200** after **26.17 seconds** for request `{ "version": 1, "seed": 42, "attempt": 0 }`. The proposal contained 256 terrain cells. It was passed directly to `SteppeValidator.validate(proposal, 42)` in Godot 4.7.2; the validator returned no errors.

A traversal using only `ExplorationState.move_to(..., true)` and legal destinations then completed **340 movement steps**, including backtracking. It discovered **254 required cells** and set **victory to true**. No terrain, position, or discovery data was edited to force the result. The two exempt corners remained excluded under the approved boundary rule. This verifies real model access, proposal parsing, deterministic geography/reachability acceptance, and exploration completion at the engine-state level; it does not claim a manual UI playthrough or acceptance of every future AI proposal.

The API key stayed in the proxy environment and was not printed or copied into the repository. The generated proposal and temporary validation runner remained under `/tmp`, outside the repository.

## Remaining limitations and human review

- **Live verification is limited to one successful Muse world**: the former Llama endpoint returned HTTP 401; after the approved migration and timeout adjustment, a live seed-42 Muse proposal passed deterministic validation and a traversal to victory. Future proposals and other accounts/deployments still require validation. The implementation follows the [official Muse Chat Completions format](https://dev.meta.ai/docs/protocols/chat-completions). Any failure preserves offline play via fallback.
- The optional proxy is a loopback development service, not a public hosted service. Public hosting/authentication are outside this MVP. See [DEPLOYMENT.md](DEPLOYMENT.md) for local startup and a private SSH-tunnel deployment procedure; the remote procedure remains unverified. The game accepts only its two documented localhost URLs. Server-to-Meta calls have a 60-second timeout; client attempts have a default 65-second timeout, at most two attempts. The timeout regression test shortens the client timeout against a fake stalled server.
- Reproduction from seed is guaranteed for the deterministic generator with the same implementation and Godot version. A live AI proposal may vary for the same seed. No model output changes action rules or an active exploration session.
- The geography family uses narrow mountain/sea projections and meandering rivers. Narrowness allows every required terrain tile to be revealed under the one-hex radius; the two approved corner exceptions remain fogged. No claims are made about terrain diversity beyond this MVP.
- Only Godot 4.7.2 on Linux was validated. Matching export templates and an actual executable build, other platforms/engine versions, and extended manual usability playtesting remain unverified.
- Human review must confirm the rule interpretations and gameplay feel before acceptance. A local commit records the implementation for review; it does not mark the work accepted. Pushing, merging, and closing Issue #1 remain separate actions.

## Files added or updated

- `project.godot`, `scenes/title.tscn`, `scenes/main.tscn`: runnable Godot project, startup presentation, and gameplay scene.
- `scripts/core/{hex_grid,steppe_rules,exploration_state,steppe_generator,steppe_validator,meta_steppe_adapter}.gd`: deterministic engine and optional proposal adapter.
- `scripts/game/{main,uki,title}.gd`: playable scene and temporary owl placeholder.
- `tests/{test_core,test_game,test_title,test_meta_adapter}.gd`, `tests/test_meta_proxy.py`: automated verification. Godot-generated `.gd.uid` companions accompany the GDScript files.
- `server/meta_proxy.py`: separate Meta-only credential-holding service.
- `docs/steppe-request.schema.json`, `docs/steppe-proposal.schema.json`: versioned contracts.
- `README.md`, `MANIFESTO.md`, `docs/IMPLEMENTATION.md`, `docs/DEPLOYMENT.md`: setup, canonical principles, architecture, deployment instructions, results, and review limitations.
- `tools/check.sh`, `.github/workflows/checks.yml`, `.gitignore`, `export_presets.cfg`: repeatable checks, CI, local-file exclusions, and Linux resource export.

`LICENSE` is unchanged. Existing IDE configuration is unchanged and ignored.
