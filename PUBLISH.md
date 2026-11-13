# Publishing to the GitHub Marketplace

A GitHub Action is published from a release of this repository. There is no package registry and no token.

## One-time setup

1. The repository must be public, and `action.yml` must be at its root (it is). The action's `name` ("AY Inbox CLI") must be unique on the Marketplace.
2. Accept the GitHub Marketplace Developer Agreement for the `ayinbox` organization: the first time you draft a release, GitHub shows the agreement in the release form. An organization owner has to accept it.
3. Turn on two-factor authentication for the account that publishes, which the Marketplace requires.

## Every release

1. Make sure CI is green on `main`.
2. Tag and push: `git tag -a v0.1.0 -m v0.1.0 && git push origin v0.1.0`. Also move a major tag for people who pin loosely, once there is a v1: `git tag -f v1 && git push -f origin v1`.
3. On GitHub, open Releases > Draft a new release, choose the tag, and tick **Publish this Action to the GitHub Marketplace**.
4. Pick a primary category (Continuous integration) and an optional second one (Utilities), check the README preview, and publish the release.

Later releases go through the same form with the box ticked; the Marketplace listing follows the newest release.
