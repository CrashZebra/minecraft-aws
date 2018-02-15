FROM alpine:latest

RUN apk add --no-cache \
          python py2-pip

RUN pip install rotate-backups

# HEALTHCHECK CMD mcstatus localhost ping

# RUN addgroup -g 1000 minecraft \
#   && adduser -Ss /bin/false -u 1000 -G minecraft -h /home/minecraft minecraft \
#   && mkdir /data \
#   && mkdir /config \
#   && mkdir /mods \
#   && mkdir /plugins \
#   && chown minecraft:minecraft /data /config /mods /plugins /home/minecraft

ADD https://github.com/itzg/rcon-cli/releases/download/1.3/rcon-cli_linux_amd64 /usr/local/bin/rcon-cli
COPY crontab /etc/crontabs/root
COPY minecraft_autobackup.sh /usr/local/bin/
COPY cron_runner.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*

VOLUME ["/data"]
WORKDIR /data

CMD ["/usr/local/bin/cron_runner.sh"]

ENV UID=1000 GID=1000 \
    RCON_HOST=server RCON_PORT=25575 RCON_PASSWORD=minecraft