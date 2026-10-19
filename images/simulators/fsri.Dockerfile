# syntax=docker/dockerfile:1
# Deployment-owned image for the FS-RI simulator test double (SPEC 15.3, 7.23.5).
#
# Build context: repos/eia-quality
#   docker build -f repos/eia-ops/images/simulators/fsri.Dockerfile -t eia/fsri-simulator:local repos/eia-quality
#
# The owning Dockerfile (simulators/fsri/Dockerfile) exposes 8080; this image keeps
# the simulator's native port 8181 so the Service, the local npm workflow, and the
# domain services' eia.fsri.base-url contract all agree.
FROM node:24-alpine

WORKDIR /app
ENV HOST=0.0.0.0 \
    PORT=8181 \
    SIM_ENV=test

COPY simulators ./simulators

EXPOSE 8181
USER node

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8181/sim/fsri/health').then((r) => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "simulators/fsri/server.mjs"]
