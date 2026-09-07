# Tasks

## 1. Protect the staged inner build tree on the outer host

- [x] 1.1 Relocate the inner stack from `/home/iris/docker-web` to `/opt/stack`
  in `Dockerfile` (the `COPY` at the former line 24).
- [x] 1.2 Repoint the permissions block to `/opt/stack`, set the stack root to
  `root:root` mode `0700`, and keep the `flags/` `0400` lockdown and the
  world-writable `html/logs` bind path (`Dockerfile`).
- [x] 1.3 Repoint the compose `CMD` to `/opt/stack/docker-compose.yaml`
  (`Dockerfile`).

## 2. Reproducible build pins and integrity checks

- [x] 2.1 Add a per-arch SHA-256 verification of the fetched static Docker CLI
  tarball in `docker-web/gallery.Dockerfile`.
- [x] 2.2 Add an explicit `ssh-keygen -A` to the gallery sshd configuration RUN
  block in `docker-web/gallery.Dockerfile`.

## 3. Self-consistent challenge content

- [x] 3.1 Remove the installed-but-unconfigured `sudo` from the gallery
  `apt-get install` line (`docker-web/gallery.Dockerfile`).
- [x] 3.2 Rewrite the vestigial `rebeca`-referencing comment to describe this
  challenge's actual user model (`docker-web/gallery.Dockerfile`).

## 4. Docs

- [x] 4.1 Update `docs/WALKTHROUGH.md` where it references the inner stack path
  and confirm no stage depends on the old location.
- [x] 4.2 Add a `2026-09-06` integrity-fixes entry to `CHANGELOG.md` and note
  the tested gallery package set.

## 5. Verify

- [x] 5.1 Run `bash -n entrypoint.sh` and confirm Dockerfiles remain coherent.
- [x] 5.2 Run `openspec validate improve-challenge-integrity --strict`.
