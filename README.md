# Uki & Kirpi — Adventures in the Great Steppe

**Uki & Kirpi — Adventures in the Great Steppe** is a top-down hex-grid exploration and puzzle adventure set in the **DAIRN: GREAT STEPPE** universe. Follow Uki, an owl who keeps a library in a lone steppe pine, and Kirpi, a curious hedgehog, as they discover winding rivers, mountain ranges, hidden treasures, and unexpected challenges. Procedurally generated geography and AI-assisted content make each journey different. The first Meta AI Hackathon MVP focuses on Uki exploring a small, continuous, hidden steppe in Godot 4; Kirpi, stone puzzles, and gold nuggets are planned for later iterations.

This implementation follows [Issue #1](https://github.com/DAIRN-Universe/uki-game/issues/1). Only Uki exploration is implemented. Human defines. AI implements. Tests verify. Human decides. Implementation is pending human review and acceptance.

## Run

Install the standard **Godot 4** editor (GDScript, no .NET required). Validated with **Godot 4.7.2 stable** on Linux; other 4.x releases have not been verified. Open `project.godot` and press **F6** on `scenes/main.tscn`, or **F5** for the main project.

```sh
godot --path . --editor --import
godot --path .
godot --path . -- --seed=42
```

Example seeds: **2026** (default), **42**, **7**. Seeds are signed 32-bit integers. The same seed reproduces the same validated offline map using the same generator and Godot version. Rejected deterministic candidates are logged and retried in a fixed order. No API key, server, Python, or internet connection is needed to play offline.

## Controls and rules

- **Q / W / E**: northwest / northeast / east. **A / S / D**: west / southwest / southeast. Hold a key to keep walking.
- **Left click**: walk to the selected adjacent steppe hex.
- **Right click**: fly to the selected steppe landing hex, at most **3 hexes** away.
- **Space**: toggle flight selection for left click. Keys continue to walk.

Walking and landing require steppe. Flights follow straight center-to-center trajectories, may cross rivers, and cannot cross or touch mountains or sea. Edge ties conservatively check both hexes. Uki moves smoothly between centers; the camera follows with smoothing. Invalid actions preserve position and discovery.

Uki reveals the current hex and six neighbors on arrival. Discovery persists for the session and revisits are allowed. Victory occurs when every required cell has been revealed; this implementation requires 254 terrain cells, including impassable cells viewed from nearby steppe. Every boundary hex must be mountain or sea. The two axial corners `(0,0)` and `(15,15)` have no interior neighbor under the one-hex reveal radius and are excluded from victory; they remain fogged. Validation proves this is possible before play. The HUD shows neither dimensions nor a completion percentage. Unknown hexes continue beyond the finite world so fog does not disclose its boundary. Discovery is not saved between runs.

## Architecture

- `scripts/core/hex_grid.gd`: axial geometry, pixel conversion, distance, and conservative flight trajectories. Regular pointy-top hexes fit nominal 72×72 bounds: radius 36, horizontal spacing `sqrt(3)*36`, vertical row spacing 54.
- `scripts/core/steppe_rules.gd`: fixed 16×16 bounds, exact approved terrain palette, deterministic legal actions, and reveal rules.
- `scripts/core/steppe_generator.gd`: seeded geography with irregular mountain projections, sea inlets, and a continuous meandering mountain-to-sea river. Up to eight validated candidates, then a known valid deterministic fallback.
- `scripts/core/steppe_validator.gd`: strict versioned schema and terrain checks, river path coverage/continuity/endpoints, steppe start, and breadth-first reachability using the actual flight rules. Every required terrain cell must be within reveal distance of a reachable steppe position; the validator also enforces the impassable boundary.
- `scripts/core/exploration_state.gd`: authoritative world copy, position, discovered cells, and victory. No rendering or AI dependency.
- `scripts/game/`: flat-color rendering with visible borders, temporary 32×32 owl placeholder, controls, interpolation, camera, and fog.
- `scripts/core/meta_steppe_adapter.gd`: optional replaceable proposal source; deterministic validation precedes acceptance. It cannot define rules or mutate an active session.
- `server/meta_proxy.py`: optional Python standard-library server, exclusively calling Meta's Llama API. It is separate from the client and excluded from the Linux export preset.

The one-hex reveal radius, steppe-only walking/landing, and conservative straight flight checks resolve details not otherwise specified by the issue. A subsequent human decision requires an impassable boundary and excludes only its two unreachable corners from victory; increasing the reveal radius is deferred to later work. No additional abilities or game systems are introduced.

## Optional Meta Llama proposals

The MVP uses **Meta technology only** for AI. The server has a fixed Meta endpoint and Meta Llama model; third-party AI providers are not integrated. The restriction belongs to this hackathon MVP; the proposal-source boundary is replaceable without changing rules, authored context, or state.

See the [deployment guide](docs/DEPLOYMENT.md) for server setup, environment variables, local operation, private remote access, Linux game packaging, and troubleshooting. The current client accepts only the documented localhost proxy addresses. Live Meta endpoint/model access has not been verified.

The [request schema](docs/steppe-request.schema.json) and [proposal schema](docs/steppe-proposal.schema.json) are version 1. Terrain is a 256-entry row-major array indexed `r*16+q`; each river is an ordered list of axial `[q,r]` river tiles, first touching mountain and last touching sea. JSON Schema is only the structural contract; deterministic GDScript additionally enforces geography and exploration rules. The server prompt supplies authored DAIRN context and constraints.

The adapter retries at most twice, with a 25-second timeout and 64 KiB response limit per attempt. Invalid JSON, invalid schema/geography, HTTP errors, oversized responses, missing credentials, and a stopped proxy all lead to the seeded offline fallback. Failure logs contain deterministic diagnostics, not remote response text or credentials. Meta is consulted only before input is enabled. Offline maps are seed-reproducible; live model output is a proposal and is not guaranteed to reproduce from a seed.

## Checks

Requirements: Godot 4 editor binary, Python 3, Bash, and `rg` (ripgrep). Mock HTTP tests require local port **8787** to be free; stop the optional proxy first.

```sh
GODOT_BIN=godot tools/check.sh
```

This imports the project, runs deterministic tests, scene tests, mock HTTP integration tests, a startup smoke check, and Python proxy tests. It fails on Godot errors even if the editor exits with status zero. No credentials or external API calls are used. The same checks are configured in `.github/workflows/checks.yml`.

For a displayed scene test and a viewport capture at `/tmp/uki-game-play.png`:

```sh
godot --path . --audio-driver Dummy --script tests/test_game.gd
```

See [implementation and verification](docs/IMPLEMENTATION.md) for recorded results, acceptance evidence, and limitations. Human playtesting and review remain required before acceptance. Linux packaging instructions and deployment limitations are maintained in the [deployment guide](docs/DEPLOYMENT.md).

## DAIRN Technology Manifesto

Read the local [DAIRN Technology Manifesto](MANIFESTO.md), reproduced from the [canonical manifesto](https://github.com/DAIRN-Universe/dairn-story-teller/blob/main/MANIFESTO.md). Its wording is preserved; only its repository-specific `docs/PRE_EXISTING.md` link points back to the source repository.

Content defines context. Deterministic rules govern actions and authoritative state. AI proposes geography within those constraints. Humans define scope and decide acceptance. No Kirpi gameplay, stones, nuggets, cooperative puzzles, quests, ability unlocks, multiplayer, or generated visual assets are implemented.
