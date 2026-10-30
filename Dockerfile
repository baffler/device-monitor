# Headless Device Monitor hub (no Electron). Only the hub's own files go in the image.
FROM node:24-alpine

# bash, coreutils, gawk and curl are only for the built-in agent that reports the NAS itself
# (it posts each report with curl). Drop them (and set NO_LOCAL_AGENT=1) if you only want the hub.
RUN apk add --no-cache tini tzdata bash coreutils gawk curl

ENV NODE_ENV=production \
    PORT=7777
WORKDIR /app
COPY server.js agent-runner.js discovery.js history.js power.js alerts.js security.js safe-json.js tailscale.js ./
COPY public ./public
COPY agent ./agent

# config.json (access key), devices.json and history live here.
# Runs as root inside the container so the ./data bind mount is writable without fixing
# ownership on the NAS first.
RUN mkdir -p /app/data
VOLUME /app/data
EXPOSE 7777/tcp 7778/udp
HEALTHCHECK --interval=60s --timeout=5s --start-period=20s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||7777)+'/api/downloads').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["/sbin/tini", "--"]
# Cap the JS heap; the hub keeps 30 days of 1-minute history per device in memory.
CMD ["node", "--max-old-space-size=128", "server.js"]
