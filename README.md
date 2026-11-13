# AY Inbox CLI action

A GitHub Action that installs `ayinbox`, the command line tool for [AY Inbox](https://ayinbox.com), and runs one command against your workspace. The command's stdout comes back as a step output, so later steps can read it.

AY Inbox is a hosted service. This repository holds a GitHub Action that runs its CLI. The service itself is not open source.

The CLI archive is downloaded from [ayinbox/ayinbox-cli](https://github.com/ayinbox/ayinbox-cli/releases) and checked against that release's `checksums.txt`. A missing or mismatched checksum stops the step before anything runs.

## Usage

```yaml
- uses: ayinbox/ayinbox-action@v0.1.0
  id: ayinbox
  with:
    api-key: ${{ secrets.AYINBOX_API_KEY }}
    command: campaign list --json
```

### Inputs

| Input | Required | Default | What it is |
|---|---|---|---|
| `command` | yes | | The command without the leading `ayinbox`, for example `campaign list --json`. Single and double quotes group words. It is split into arguments and never run through a shell |
| `api-key` | yes | | An AY Inbox API key (`aybox_...`), from a secret. It reaches the CLI as `AYINBOX_TOKEN` and is masked in logs |
| `version` | no | `latest` | A CLI release tag such as `v1.2.3`, or `latest` |
| `api-url` | no | | The API base URL, only when it is not the default `https://api.ayinbox.com` |

### Outputs

| Output | What it is |
|---|---|
| `stdout` | What the command printed on stdout. Output is JSON when the CLI is not writing to a terminal, which is always the case here |
| `exit-code` | The command's exit code. A non-zero code also fails the step |
| `version` | The CLI version that was installed |

Runs on Linux, macOS and Windows runners, X64 and ARM64. The installed binary is also on `PATH` for later steps.

## Example: list campaigns as JSON in CI

```yaml
name: Campaign report

on:
  workflow_dispatch:

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: ayinbox/ayinbox-action@v0.1.0
        id: campaigns
        with:
          api-key: ${{ secrets.AYINBOX_API_KEY }}
          command: campaign list --all --json

      - name: Summarise
        env:
          CAMPAIGNS: ${{ steps.campaigns.outputs.stdout }}
        run: |
          echo "$CAMPAIGNS" | jq -r '.data[] | "\(.status)\t\(.name)"' >> "$GITHUB_STEP_SUMMARY"
```

## Example: check mailbox health on a schedule

Fails the run when a mailbox is not active or its SPF or DMARC check is failing, so GitHub notifies you.

```yaml
name: Mailbox health

on:
  schedule:
    - cron: "0 7 * * 1-5"
  workflow_dispatch:

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: ayinbox/ayinbox-action@v0.1.0
        id: mailboxes
        with:
          api-key: ${{ secrets.AYINBOX_API_KEY }}
          command: mailbox list --all --json

      - name: Report mailboxes that need attention
        env:
          MAILBOXES: ${{ steps.mailboxes.outputs.stdout }}
        run: |
          trouble=$(echo "$MAILBOXES" | jq -r '.data[]
            | select((.status != "active") or (.auth_state == "failing"))
            | "\(.email)\tstatus=\(.status)\tauth=\(.auth_state)"')
          if [ -n "$trouble" ]; then
            echo "$trouble" | tee -a "$GITHUB_STEP_SUMMARY"
            exit 1
          fi
          echo "All mailboxes are active and passing authentication checks." >> "$GITHUB_STEP_SUMMARY"
```

## Keys and safety

- Use a key with only the scopes the job needs. Both examples above work with a read-only key: create one in the dashboard under Settings > API keys, or with `ayinbox auth login --scopes read-only` and `ayinbox key` on your machine.
- Commands that send mail or start campaigns (`campaign start`, `campaign test`, `mailbox send`, `inbox reply`, `inbox compose`, `inbox approve-draft`, placement tests) refuse to run without `--yes`, because there is no terminal to confirm on. The action never adds `--yes` for you. Starting a campaign also needs a key with the `SEND_CAMPAIGNS` scope.
- Pin the action to a release tag or a full commit SHA.

## Documentation

- [CLI reference](https://docs.ayinbox.com/api/cli/)
- [Permissions](https://docs.ayinbox.com/api/permissions/)

Access to AY Inbox: invite only for now. Write to team@ayinbox.com.

## Licence

The action's own code is MIT licensed (see [LICENSE](LICENSE)). The `ayinbox` binary it installs is proprietary and free to use with an AY Inbox account; its licence is in [ayinbox/ayinbox-cli](https://github.com/ayinbox/ayinbox-cli/blob/main/LICENSE).
