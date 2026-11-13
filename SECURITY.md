# Security

Please report a vulnerability in this action, or in the CLI it installs, by email to team@ayinbox.com. Do not open a public issue for it.

The action downloads the CLI over HTTPS from github.com/ayinbox/ayinbox-cli and refuses to install an archive whose SHA-256 does not match the release's `checksums.txt`. The `command` input is split into arguments and never passed through a shell, and the API key is masked in logs.
