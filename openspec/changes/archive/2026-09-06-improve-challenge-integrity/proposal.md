# Improve challenge integrity

## Why

The adversarial review of this challenge (2026-09-06) confirmed the documented
solution path works end to end, but flagged a set of hygiene and
reproducibility defects that weaken the challenge without blocking a solve:

- The inner Docker stack is staged under the outer player's home
  (`/home/iris/docker-web`) at directory mode `0755`, so the unprivileged outer
  account `iris` can read the inner-stack secrets, the first inner flag source,
  milo's credential note, and the socket-breakout notes before ever performing
  the intended escalation.
- The gallery image installs `sudo` but never configures it, an unconfigured
  tool that misleads without being a deliberate, documented red herring.
- A leftover build comment references `rebeca`, an account from an unrelated
  challenge, contradicting this challenge's actual user model.
- The gallery's sshd host keys are generated implicitly by the package
  postinst rather than explicitly, unlike the outer image, so a build variation
  can leave the container without host keys.
- The static Docker CLI is fetched over the network with no integrity check, so
  a compromised mirror or MITM with a trusted CA could substitute a different
  binary into the build.

## What Changes

- **ADDED** requirement: the staged inner build tree is protected on the outer
  host so its secrets, keys, and flag values are not readable by the
  unprivileged outer account (relocate the stack out of any player home).
- **ADDED** requirement: reproducible build pins and integrity checks so the
  fetched static Docker CLI is verified against a known SHA-256, and the
  gallery's sshd host keys are generated explicitly.
- **ADDED** requirement: challenge content is self-consistent, carrying no
  installed-but-unconfigured tooling that misleads and no vestigial reference to
  an unrelated challenge.

## Impact

- Affected: challenge content and docs only (`Dockerfile`,
  `docker-web/gallery.Dockerfile`, `docs/WALKTHROUGH.md`, `CHANGELOG.md`).
- No scoring change and no flag-value change: every flag keeps its value and
  stays reachable by its intended reader; only the inner stack's path on the
  outer host and file permissions change.
- No git commit is made; all edits are left uncommitted in the working tree.
