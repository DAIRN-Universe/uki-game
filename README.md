# Uki & Kirpi — Adventures in the Great Steppe

A top-down hex-grid exploration adventure set in the **DAIRN: GREAT STEPPE** universe. Uki, an owl who keeps a library in a lone steppe pine, explores winding rivers, mountains, and unknown landscapes. Each journey features a procedurally generated steppe shaped by AI-assisted proposals and verified game rules.

**Current MVP:** Play as **Uki** in a 16×16 hex steppe, discover hidden terrain, walk and fly between hexes, and reveal every required area. Built with **Godot 4** for **Meta AI Hackathon 2026**. The optional Meta **Muse Spark** integration proposes geography; deterministic validation and an offline generator keep the game playable without an API connection.

**Coming later:** Kirpi, stone-pushing puzzles, hidden gold nuggets, and cooperative adventures.

## Play locally

Install Godot 4 (GDScript edition), open `project.godot`, and press **F5**. Select **PLAY** on the title screen. No API key or internet connection is required for offline play.

| Control | Action |
| --- | --- |
| Q / W / E | Move northwest / northeast / east |
| A / S / D | Move west / southwest / southeast |
| Left click | Walk to an adjacent steppe hex |
| Right click | Fly to a valid landing hex (up to 3 hexes) |
| Space | Toggle flight selection for left click |

Mountains and sea are impassable. Fly over rivers, uncover the map, and explore at your own pace.

## Documentation

- [DAIRN Technology Manifesto](MANIFESTO.md) — principles governing content, rules, AI, and human decisions
- [Implementation and verification](docs/IMPLEMENTATION.md) — architecture, test evidence, and known limitations
- [Deployment guide](docs/DEPLOYMENT.md) — optional Meta proxy, packaging, and deployment
- [Steppe request schema](docs/steppe-request.schema.json) · [Proposal schema](docs/steppe-proposal.schema.json)
- [MVP specification — Issue #1](https://github.com/DAIRN-Universe/uki-game/issues/1)

## Development

Run the automated checks with:

```sh
GODOT_BIN=godot tools/check.sh
```

The game uses deterministic rules and state; AI-generated geography is a proposal that must pass validation before use. All AI functionality in this hackathon MVP uses **Meta technologies only**.

## License

See [LICENSE](LICENSE) for the repository's code license. Original DAIRN characters, artwork, logos, and narrative materials may have separate rights; check their accompanying notices.
