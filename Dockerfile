FROM ubuntu:24.04

# Base packages for the outer CTF host: its own Docker engine plus sshd.
RUN apt-get update \
    && apt-get install -y docker.io docker-compose-v2 openssh-server nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Setup docker env + ssh env" \
    && mkdir -p /var/lib/docker /run/sshd \
    && sed -i "s/#PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config \
    && ssh-keygen -A \
    && echo "Adding user iris" \
    && useradd -m -s /bin/bash iris \
    && echo -n "iris:1UZfQoJerhXHgM4KiClR" | chpasswd \
    && userdel ubuntu \
    && echo "Linking .bash_history to /dev/null" \
    && ln -sf /dev/null /root/.bash_history \
    && ln -sf /dev/null /home/iris/.bash_history

# Copying flags + inner stack sources
COPY ./main_flags/root.txt /root/root.txt
COPY ./main_flags/user.txt /home/iris/user.txt
# The inner stack is staged outside any player home so the unprivileged outer
# account (iris) cannot read its secrets, first-flag source, or breakout notes
# before performing the intended escalation.
COPY ./docker-web /opt/stack

# The recovered credential for the outer host. iris keeps her own SSH password in
# a backup config in her home. It is only reachable once the player is root on the
# outer filesystem (through the mounted Docker socket), which is the intended way
# to pivot from the inner container to an interactive session on the outer host.
RUN mkdir -p /home/iris/.backup \
    && printf '%s\n' '# gallery deploy credentials (do not commit)' 'ssh_user=iris' 'ssh_pass=1UZfQoJerhXHgM4KiClR' > /home/iris/.backup/credentials.conf \
    && chown -R iris:iris /home/iris/.backup \
    && chmod 0700 /home/iris/.backup \
    && chmod 0600 /home/iris/.backup/credentials.conf

RUN echo "Permissions for flags" \
    && chown root:root /root/root.txt && chmod 0400 /root/root.txt \
    && chown iris:iris /home/iris/user.txt && chmod 0400 /home/iris/user.txt \
    && echo "Permissions for inner stack sources" \
    && chown -R root:root /opt/stack && chmod 0700 /opt/stack \
    && chmod 0400 -R /opt/stack/flags \
    && mkdir -p /opt/stack/html/logs && chmod 0777 /opt/stack/html/logs

# Store the inner Docker engine's data on a volume so the nested engine does not
# run overlay-on-overlay (matches the official docker:dind image). Without this,
# inner image builds fail on hosts whose /var/lib/docker is itself an overlay
# filesystem (for example Docker Desktop).
VOLUME /var/lib/docker

EXPOSE 22 23 8080

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["docker", "compose", "-f", "/opt/stack/docker-compose.yaml", "up"]
