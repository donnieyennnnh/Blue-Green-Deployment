# syntax=docker/dockerfile:1.7
#
# Multi-stage build:
#   Stage 1 (deps):   install *production* dependencies from the lockfile
#   Stage 2 (runner): copy only node_modules + source into a slim final image
#
# Why multi-stage? The final image contains no npm cache, no dev tooling,
# no source control files — just Node, our code, and prod deps. Smaller
# attack surface and faster pulls on EC2.

# ---- Stage 1: dependencies ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# `npm ci` is strict: fails fast if package.json and lockfile disagree.
# `--omit=dev` skips devDependencies (nothing in them yet, but future-proof).
RUN npm ci --omit=dev

# ---- Stage 2: runtime ----
FROM node:20-alpine AS runner
WORKDIR /app

# Copy with ownership set to the built-in `node` user (uid 1000) so the
# app can read its own files after we drop privileges below.
COPY --chown=node:node --from=deps /app/node_modules ./node_modules
COPY --chown=node:node src ./src
COPY --chown=node:node package.json ./

# Run as unprivileged user. If the app is ever exploited, the attacker
# lands as `node` not `root` — much smaller blast radius inside the container.
USER node

ENV NODE_ENV=production
ENV APP_PORT=3000
EXPOSE 3000

# Node 20 handles PID-1 signal forwarding correctly, so no `tini` needed.
CMD ["node", "src/server.js"]
