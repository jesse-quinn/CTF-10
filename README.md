# Stego Gallery CTF

Stego Gallery CTF is a Capture The Flag challenge that runs as a single
privileged Docker container. Inside it, an outer host runs its own Docker engine
and deploys an image gallery served by nginx. The published photos hide
credentials in their metadata; from there the challenge walks through an image
server login, a classic tar wildcard privilege escalation to container root, and
finally a break back out to the outer host through a mounted Docker socket.

There are five flags:

| Flag file | Location | Prefix |
|---|---|---|
| dunes.jpg metadata | gallery container, served image | `FLAG{...}` |
| milo.txt | gallery container, user `milo` | `FLAG{...}` |
| stego-root.txt | gallery container, `root` | `STEGO_FLAG{...}` |
| user.txt | outer host, user `iris` | `MAIN_FLAG{...}` |
| root.txt | outer host, `root` | `MAIN_FLAG{...}` |

## Requirements

- Docker Engine that can run a privileged container (Docker Desktop works).
- Internet access on the first run: the inner stack pulls its base image (nginx)
  and a static Docker client at build time, and the final breakout pulls a small
  helper image.
- Works on both amd64 and arm64 hosts.

## Running the challenge

```bash
git clone https://github.com/jesse-quinn/CTF-10.git
cd CTF-10
docker image build -t stego-gallery-ctf:latest .
docker container run -it --rm --privileged \
  --hostname stego-gallery-ctf --name stego-gallery-ctf \
  -p 8080:8080 -p 22:22 -p 23:23 \
  stego-gallery-ctf:latest
```

Run the build and run from inside the cloned `CTF-10` directory. On Docker
Desktop (macOS, Windows) do not use `sudo`; on a Linux host, prefix both
commands with `sudo` or add your user to the `docker` group.

Then wait for the inner Docker Compose stack to finish deploying. The gallery is
served on port 8080, the outer host SSH on port 22, and the gallery container
SSH on port 23.

Note: if you use `-d`, you will not see the inner Compose deployment progress.

If some of those host ports are already in use on your machine, remap the left
side of each `-p` flag (for example `-p 18080:8080 -p 2222:22 -p 2323:23`); the
challenge itself is unaffected.

## Rules

- Do not read the flag files or the solution notes during setup. The challenge
  is finding them through gameplay.
- The intended solution path is documented, for maintainers, in
  `docs/WALKTHROUGH.md`. It is a spoiler; do not open it if you want to play.

## Credits

This is an original challenge inspired by the Himanshukr000/CTF-DOCKERS
collection and themed on forensics and steganography. It reuses the
docker-in-docker scaffolding from the maintained Docker-in-Docker CTF; see
`CHANGELOG.md` and `LICENSE`.
