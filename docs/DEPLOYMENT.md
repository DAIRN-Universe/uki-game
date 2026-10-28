# Deployment guide

This guide describes the current Issue #1 MVP. The game runs offline without a server. Optional AI geography proposals use a separate Python proxy that holds the Meta API key; the Godot client validates every proposal before accepting it.

The supported network arrangement is a **private loopback proxy**. For a remote Linux host, use an SSH tunnel so the client can keep its existing localhost URL. Public HTTP/HTTPS hosting, client authentication, containers, and automatic service installation are not implemented. No game rules or client URL restrictions need to change for the arrangement below.

## Requirements and deployment files

- Game workstation: standard Godot 4 editor to run from source, or a Linux executable and its matching `.pck` file. The implementation was validated with Godot 4.7.2 on Linux x86_64.
- Proxy host: Python 3 with standard-library `ssl` support. No `pip` packages are needed. It must be able to reach the fixed Meta endpoint over HTTPS.
- Optional remote arrangement: SSH access to the Linux proxy host and an SSH client on the game workstation.
- Meta mode: an authorized API key and access to the configured Meta Muse Spark model. One live proposal was verified on 2026-10-29 using an authorized account; your own account still needs the required access.

Use a reviewed revision of the source tree. The proxy needs these two files in this relative layout:

```text
uki-game/
├── server/
│   └── meta_proxy.py
└── docs/
    └── steppe-proposal.schema.json
```

Deploy both files together. The server loads the schema at startup using its own file location. A full source checkout also works. The game export excludes `server/` and `docs/`, so an exported game does not contain the proxy deployment files.

Do not copy credentials into the project or game distribution. Review and acceptance remain human decisions. The human confirmed a manual playthrough and approved publication; see Issue #1 for the publication and CI record.

## Configuration

| Setting | Where it is used | Current behavior |
| --- | --- | --- |
| `MODEL_API_KEY` | Python proxy environment only | Required for live Meta calls; a missing key produces HTTP 503 and the game falls back offline. |
| `UKI_META_PROXY_URL` | Game process environment | Unset or empty selects offline mode. Meta mode accepts only `http://127.0.0.1:8787/steppe` or `http://localhost:8787/steppe`. Prefer the explicit IPv4 address. |
| Proxy listener | Fixed in `server/meta_proxy.py` | `127.0.0.1:8787`; no host/port environment override. |
| Meta endpoint | Fixed in `server/meta_proxy.py` | `https://api.meta.ai/v1/chat/completions`. |
| Meta model | Fixed in `server/meta_proxy.py` | `muse-spark-1.3`. |

The proxy reads `MODEL_API_KEY` from its process environment when handling a proposal. It does not read the former `LLAMA_API_KEY` variable. The endpoint, model, developer-role instructions, and `choices[0].message.content` response shape follow the [official Meta Chat Completions documentation](https://dev.meta.ai/docs/protocols/chat-completions). Structured output requests use the [documented JSON Schema format](https://dev.meta.ai/docs/structured-output); all game-rule validation remains deterministic in GDScript. It does not automatically load `.env` files. Endpoint and model names are not environment-configurable in this version; confirm model access before relying on live generation.

## Migrating from the original Llama proxy

A human-approved change replaces the original Llama endpoint/model with Meta Muse Spark. Stop an existing proxy with Ctrl+C and restart it after updating the code. A process already running the old script keeps its old endpoint, response parser, and environment-variable name until restarted.

If the value you already entered under `LLAMA_API_KEY` is actually your **Meta Model API / Muse key**, you can move it in the same Bash terminal without displaying or retyping it:

```bash
export MODEL_API_KEY="$LLAMA_API_KEY"
unset LLAMA_API_KEY
python3 -u server/meta_proxy.py
```

This only renames the environment variable. It does not convert a Llama credential into a Muse credential; obtain the correct key from your Meta Model API account if necessary. Alternatively, use the fresh key-entry procedure below. Endpoint/model overrides and third-party providers are not introduced.

## Local proxy startup

Open a Bash terminal in the repository root. Read the key without echoing it or putting its value in shell history:

```bash
read -rsp 'Meta API key: ' MODEL_API_KEY
printf '\n'
export MODEL_API_KEY
python3 -u server/meta_proxy.py
```

The proxy prints its loopback listening address and stays in the foreground. Keep this terminal open. Other processes with sufficient access to the same host/account may inspect process environments; use a trusted account and host. Never print the variable or put its value in client configuration.

In a second terminal, start the game from the repository root:

```bash
UKI_META_PROXY_URL=http://127.0.0.1:8787/steppe godot --path . -- --seed=42
```

After **DAIRN PRESENT**, select **PLAY** on the **UKI** title screen. The game then considers proposals before enabling exploration input. Each client attempt has a default 65-second timeout and 64 KiB response limit, with at most two attempts. The proxy uses a 60-second upstream request timeout. Rejected or unavailable proposals cause deterministic offline generation with the requested seed.

To run offline explicitly, without using a previously configured proxy variable:

```bash
UKI_META_PROXY_URL= godot --path . -- --seed=42
```

## Private remote proxy over SSH

This arrangement keeps the Meta key on the remote host. Port 8787 remains bound to remote loopback; no public listener or public firewall opening is required for it.

1. Copy the reviewed proxy and schema files to the remote host, preserving the layout shown above, or use an existing reviewed source checkout there.
2. Open an SSH terminal to that host. Change to its `uki-game` directory and run the **Local proxy startup** commands there. Enter `MODEL_API_KEY` on the remote host. Keep the remote process running in that terminal; this procedure does not install a persistent service.
3. In another terminal on the game workstation, create the tunnel, replacing `user@proxy-host` with your SSH destination:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:8787:127.0.0.1:8787 user@proxy-host
```

Keep the tunnel running. Local port 8787 must be free: stop a local proxy or other listener before creating it. The game continues to use its unchanged local URL:

```bash
UKI_META_PROXY_URL=http://127.0.0.1:8787/steppe godot --path . -- --seed=42
```

The SSH tunnel encrypts the workstation-to-host connection. The remote proxy calls Meta over HTTPS. The API key is neither sent to the game nor needed on the workstation. Tunnel failure or remote proxy failure leads to offline fallback.

This procedure has not been exercised against a remote host during implementation. Use trusted SSH host credentials and your existing SSH host-key verification process.

## Verification and smoke checks

### Offline automated checks

In a source checkout, install Godot, Python 3, Bash, and ripgrep, then run:

```bash
GODOT_BIN=godot tools/check.sh
```

Stop the optional proxy and SSH tunnel first: the adapter test binds local port 8787. The script clears live-AI environment settings in its own process and uses a fake HTTP server. It does not call Meta or require a key.

### HTTP transport check

With a local proxy or tunnel running, use this deliberately invalid request:

```bash
curl --silent --show-error --include \
  -H 'Content-Type: application/json' \
  --data '{}' \
  http://127.0.0.1:8787/steppe
```

Expect **HTTP 400** and `{"error": "Invalid v1 request"}`. This proves the proxy handler is reachable without making a Meta call. There is no dedicated health endpoint; `GET /steppe` is not a health check.

### Optional live Meta check

The following request makes a live Meta call when the proxy has a key and can consume API quota:

```bash
curl --silent --show-error --include --max-time 70 \
  -H 'Content-Type: application/json' \
  --data '{"version":1,"seed":42,"attempt":0}' \
  http://127.0.0.1:8787/steppe
```

- **HTTP 200**: the server parsed a proposed world. This alone does not establish valid geography; only the deterministic game validator can accept the proposal.
- **HTTP 503** with `Meta proposal unavailable`: inspect the safe `code` field and, for upstream HTTP errors, `upstream_status`. The same fixed diagnostic is printed in the proxy terminal. Keys, exception messages, request headers, and response bodies remain redacted.

| Diagnostic code | Meaning / next check |
| --- | --- |
| `missing_api_key` | `MODEL_API_KEY` is absent or empty in the proxy process. Export it in the same terminal and restart the proxy. |
| `meta_unauthorized` | Meta returned HTTP 401. Check that the key is valid for the configured Meta endpoint. |
| `meta_forbidden` | Meta returned HTTP 403. Check account permissions and endpoint/model access. |
| `meta_not_found` | Meta returned HTTP 404. Check the configured endpoint and model; the status alone does not identify which is unavailable. |
| `meta_bad_request` | Meta returned HTTP 400. The model/request contract needs investigation. |
| `meta_rate_limited` | Meta returned HTTP 429. Check quota/rate limits. |
| `meta_timeout` | The upstream operation timed out. |
| `meta_dns_error`, `meta_tls_error`, `meta_network_error` | Check DNS, certificates, connectivity, and the server's network configuration. |
| `meta_redirect_refused` | An upstream redirect was blocked to prevent credential forwarding. |
| `meta_invalid_json`, `meta_invalid_response`, `meta_response_too_large` | Meta returned an unusable or oversized response. |
| `meta_unavailable`, `meta_http_error` | Inspect the numeric `upstream_status`; the remote response text is not exposed. |
| `internal_error` | An unclassified internal failure occurred; no exception details are exposed. |

Then launch the game with the proxy URL and verify play. A playable map alone does not prove a live proposal was accepted because fallback is intentional. Check the game process output for Meta rejection/unavailability warnings; the automated adapter suite separately verifies acceptance and fallback using controlled responses. A live seed-42 proposal was verified on 2026-10-29: HTTP 200 in 26.17 seconds, deterministic validation passed, and a legal engine-state traversal revealed all 254 required cells and triggered victory. This evidence does not replace manual UI playtesting or account-specific verification on another deployment.

## Linux game packaging and distribution

On the build workstation, install Godot 4.7.2 and its matching **export templates**. From the repository root:

```bash
godot --headless --path . --editor --import
mkdir -p builds
godot --headless --path . --export-release Linux
```

The `Linux` preset targets x86_64 and writes `builds/uki-game.x86_64`. Embedded PCK is disabled, so distribute its generated `uki-game.pck` alongside the executable. Keep the executable permission when copying files.

From the distribution directory:

```bash
./uki-game.x86_64 -- --seed=42
```

For optional Meta mode with a local proxy or active tunnel:

```bash
UKI_META_PROXY_URL=http://127.0.0.1:8787/steppe \
  ./uki-game.x86_64 -- --seed=42
```

The export preset excludes server code, schemas/documentation, tests, tools, GitHub configuration, and `.env` files. The proxy and its schema must be deployed separately if AI proposals are wanted. Never add API keys to the game project, export preset, launcher, or distributed files.

**Verification boundary:** resource archive export and its exclusions were checked; an executable export and distributed-binary startup have not been tested. Validate the built executable on the target machine before distribution. Windows, macOS, and web export presets are not provided.

## Stop, restart, and update

- **Stop a foreground proxy:** press Ctrl+C in its terminal. Use `unset MODEL_API_KEY` afterward if the shell remains open and no longer needs the key.
- **Stop an SSH tunnel:** press Ctrl+C in the tunnel terminal.
- **Restart with a new key:** stop the proxy, read/export the new key, and start the proxy again. Setting the variable in another shell does not change the running server's environment.
- **Update proxy code:** stop the proxy, replace both the proxy and matching schema from the reviewed revision, then restart. Repeat the HTTP transport check and an offline/game smoke check.
- **Update the game:** replace the executable and its matching PCK together. Keep the previous reviewed pair if a rollback is needed.

Proxy and game protocol versions must remain compatible with the version 1 request/proposal schemas. The check workflow runs verification only; it does not perform remote deployment, install a process manager, configure automatic restart, or publish release binaries.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `Address already in use` | Another proxy, tunnel, or mock test owns port 8787. Stop it before starting the desired listener. |
| Schema file missing on proxy startup | Deploy `docs/steppe-proposal.schema.json` alongside `server/` using the documented directory layout. |
| Client rejects the proxy URL | Use one of the two exact localhost URLs, including `/steppe`. For a remote host, use the SSH tunnel. |
| HTTP 400 | Send the exact v1 request fields: integer `version=1`, signed 32-bit integer `seed`, and integer `attempt` of 0 or 1. |
| HTTP 503 | Read `code` and optional `upstream_status` using the table above. Restart an older proxy process after code updates. No `.env` loader is installed. |
| Game plays despite server failure | Expected: deterministic fallback preserves offline play. Check game warnings to distinguish rejection/failure paths. |
| No per-request proxy logs | HTTP access logs and upstream exception details are suppressed. Failures print only fixed diagnostic codes and numeric HTTP status. Do not add token/header/body dumps. |
| Export cannot find templates | Install templates matching the Godot editor version. Resource archive validation does not substitute for an executable build. |

For implementation evidence and remaining acceptance limitations, see [IMPLEMENTATION.md](IMPLEMENTATION.md). For game controls and architecture, see [README.md](../README.md).
