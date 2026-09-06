# Changelog

## Initial release

Original forensics and steganography challenge built on the docker-in-docker
scaffolding of the Docker-in-Docker CTF. An outer Ubuntu host runs its own Docker
engine and deploys an nginx image gallery; the intended path runs from hidden
image metadata to container root and back out to the outer host.

### Added

- Outer host (`FROM ubuntu:24.04`) that runs `dockerd` and `sshd` and brings up
  the inner stack with Docker Compose on start, matching the reference layout.
- Inner gallery container (`FROM nginx:1.30.4`) serving a browsable set of photos.
  The images are generated at build time and one of them, `dunes.jpg`, carries
  two independent pieces of hidden data:
  - the first inner flag in an EXIF `UserComment`, stored as plain ASCII so it is
    recoverable with `exiftool` or `strings`;
  - milo's SSH credential in an uncompressed zip appended after the JPEG data, so
    `unzip`, `binwalk`, and `strings` all recover it.
- A tar wildcard privilege escalation: a root cron job archives a world-writable
  staging directory once a minute with a bare `*`, so `milo` can drop
  `--checkpoint` and `--checkpoint-action=exec` files and run code as container
  root (GTFOBins tar wildcard technique). The interval is one minute so the
  escalation is verifiable during a solve.
- The final escape reuses the reference approach: the outer Docker socket is
  mounted into the gallery container and a static Docker client is installed, so
  container root can mount the outer host filesystem, read the outer root flag,
  and recover `iris`'s SSH credential to pivot onto the outer host for the user
  flag.

### Notes

- Base images are pulled at runtime rather than baked as tarballs, so the
  challenge is multi-arch (amd64 and arm64).
- `VOLUME /var/lib/docker` is declared on the outer image so the nested engine
  does not run overlay-on-overlay, which otherwise breaks inner builds on hosts
  whose `/var/lib/docker` is itself an overlay filesystem.
- All flag values and planted credentials are freshly generated for this release.
