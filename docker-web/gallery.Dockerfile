FROM nginx:1.30.4

ARG DOCKER_CLI_VERSION=29.8.0

# Software: sshd for the user pivot, cron and GNU tar for the backup job, plus the
# imaging tools used at build time to generate the gallery and embed the hidden
# data. curl and ca-certificates fetch the static Docker client for the final
# socket breakout.
RUN apt-get update && \
    apt-get install -y nano openssh-server cron tar curl ca-certificates \
        imagemagick libimage-exiftool-perl zip && \
    echo "Installing a static Docker CLI (used for the final socket breakout)" \
    && arch="$(uname -m)" \
    && case "$arch" in \
         x86_64)  docker_cli_sha256="cc21815cf1e2efed867dc9c8b96b46ffed8ea176ffab32b0aacb54726ded8f25" ;; \
         aarch64) docker_cli_sha256="1462a696be6029bd478d7d60d7f3c31cdd15affd1178a4a278aaf4a1d1b7f8b5" ;; \
         *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://download.docker.com/linux/static/stable/${arch}/docker-${DOCKER_CLI_VERSION}.tgz" -o /tmp/docker.tgz \
    && echo "${docker_cli_sha256}  /tmp/docker.tgz" | sha256sum -c - \
    && tar -xzf /tmp/docker.tgz -C /usr/local/bin --strip-components=1 docker/docker \
    && rm -f /tmp/docker.tgz

# Users and passwords. This challenge has a single non-root user, milo, whose
# password is the credential hidden inside one of the gallery images; there are
# no decoy accounts.
RUN useradd -m -s /bin/bash milo && \
    echo "milo:a1KSpvKXWhw6jQkY7N" | chpasswd && \
    ln -sf /dev/null /home/milo/.bash_history && \
    ln -sf /dev/null /root/.bash_history && \
    mkdir -p /var/run/sshd && \
    ssh-keygen -A && \
    sed -i 's/#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Flags
COPY --chown=milo:milo --chmod=400 ./flags/milo.txt /home/milo/milo.txt
COPY --chown=root:root --chmod=400 ./flags/stego-root.txt /root/stego-root.txt

# Web content and the backup job
COPY ./default.conf /etc/nginx/conf.d/default.conf
COPY ./html/index.html /usr/share/nginx/html/gallery/index.html
COPY --chmod=644 ./crontab /etc/crontab

# Generate the gallery images and embed the hidden data at build time.
#  - dunes.jpg carries the first inner flag in an EXIF UserComment (readable with
#    exiftool, and stored as plain ASCII so strings finds it too).
#  - the same file has an uncompressed sidecar zip appended after the JPEG data,
#    so unzip, binwalk, and strings all recover milo's credential note.
COPY ./secrets/usercomment.txt /build/usercomment.txt
COPY ./secrets/note.txt /build/note.txt
RUN set -e; \
    imgdir=/usr/share/nginx/html/gallery/images; \
    mkdir -p "$imgdir"; \
    convert -size 1024x768 gradient:'#20364f-#050810' -blur 0x8 "$imgdir/harbor.jpg"; \
    convert -size 1024x768 gradient:'#c9a26b-#2b1c0e' -blur 0x8 "$imgdir/dunes.jpg"; \
    convert -size 1024x768 gradient:'#33475e-#0a0f18' -blur 0x8 "$imgdir/pier.jpg"; \
    convert -size 1024x768 gradient:'#4a5a4f-#0c110d' -blur 0x8 "$imgdir/cliffs.jpg"; \
    exiftool -overwrite_original -UserComment="$(cat /build/usercomment.txt)" "$imgdir/dunes.jpg"; \
    cd /build && zip -0 -q sidecar.zip note.txt && cat sidecar.zip >> "$imgdir/dunes.jpg"; \
    rm -rf /build

# Wildcard-injection backup staging: root's cron job archives this directory once
# a minute with a bare wildcard, and the directory is world-writable, so any user
# who can drop files here can smuggle tar options into the command line.
RUN mkdir -p /var/backups/site && \
    printf '%s\n' 'staging directory for the gallery backup job' > /var/backups/site/README && \
    chmod 0777 /var/backups/site && \
    mkdir -p /usr/share/nginx/html/gallery/logs && \
    chown -R nginx:nginx /usr/share/nginx/html/gallery && \
    chown root:root /usr/share/nginx/html/gallery/logs && \
    chmod 0777 /usr/share/nginx/html/gallery/logs

# Drop the build-time imaging tools to keep the runtime image lean.
RUN apt-get purge -y imagemagick libimage-exiftool-perl zip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 8080 22

CMD service ssh start && service cron start && nginx -g 'daemon off;'
