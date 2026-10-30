# Security and privacy

GoDot Game Gallery is an offline-first local development tool. It does not collect telemetry or send game code anywhere. Setup downloads official Godot release assets over HTTPS and verifies their SHA-256 against the repository lock file.

Game scripts are ordinary executable programs and should come from people you trust. Process separation provides project isolation, not a security sandbox. Manifests cannot provide arbitrary shell commands; tooling rejects paths that escape game folders.

Do not commit credentials, signing keys, or personal data in sample games. For a vulnerability, use GitHub's private vulnerability reporting if enabled on the hosted repository. Do not post exploit details or secrets in a public issue.
