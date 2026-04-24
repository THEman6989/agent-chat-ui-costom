# Stufe 1: Abhängigkeiten installieren
FROM node:20-alpine AS deps
# libc6-compat wird oft für native Abhängigkeiten in Alpine benötigt
RUN apk add --no-cache libc6-compat
# Spezifische pnpm Version aus der package.json installieren
RUN npm install -g pnpm@10.5.1
WORKDIR /app

# Kopiere Lockfiles für die Installation
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --no-frozen-lockfile

# Stufe 2: Den Build erstellen
FROM node:20-alpine AS builder
RUN npm install -g pnpm@10.5.1
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js sammelt anonyme Telemetriedaten während des Builds. Deaktivierung:
ENV NEXT_TELEMETRY_DISABLED 1

RUN pnpm build

# Stufe 3: Runner-Image (das eigentliche Image)
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

# Erstelle einen dedizierten User für mehr Sicherheit
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Kopiere nur die notwendigen Dateien aus dem Builder
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

# Nutzt das in der package.json definierte Start-Script
CMD ["sh", "-c", "npx pnpm start"]
