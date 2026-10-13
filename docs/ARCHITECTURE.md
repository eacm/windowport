# Architecture

## Product boundary

WindowPort publishes applications, not desktops. A Windows administrator chooses
an allowlisted catalog. The client can discover, launch, and interact only with
that catalog. This keeps the product understandable and creates a clear security
boundary for future pairing and policy work.

```text
iPhone / iPad                  Windows PC
┌─────────────────┐            ┌─────────────────────────┐
│ SwiftUI catalog │── HTTPS ──▶│ Catalog + session API   │
│ Session surface │◀─ video ───│ Per-window capture      │
│ Touch / keyboard│── input ──▶│ Scoped input injection  │
└─────────────────┘            └─────────────────────────┘
```

## MVP protocol

| Endpoint | Purpose |
|---|---|
| `GET /api/health` | Host readiness |
| `GET /api/apps` | Published app catalog |
| `POST /api/apps/{id}/launch` | Start or focus an app and create a session |
| `GET /api/sessions/{id}/stream` | MJPEG frames for the selected window |
| `POST /api/sessions/{id}/pointer` | Normalized pointer input |
| `POST /api/sessions/{id}/text` | Text input |

MJPEG is a bootstrap transport, not the release transport. The intended next
step is WebRTC (H.264/HEVC video, audio, data channel input, congestion control)
behind the same `WindowPortServing` client abstraction.

## Security roadmap

1. Pair with a one-time code and pin a host identity.
2. Use TLS everywhere and store client credentials in Keychain/DPAPI.
3. Bind sessions to one published app and reject arbitrary paths.
4. Add consent, connection visibility, revocation, and audit logs on Windows.
5. Sign/notarize clients and ship automatic security updates.
6. Add rate limits and protocol fuzzing before internet relay support.

