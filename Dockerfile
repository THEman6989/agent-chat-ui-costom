# Stufe 1: Abhängigkeiten installieren
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat
RUN npm install -g pnpm
WORKDIR /app

# Kopiere Lockfiles für die Installation
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Stufe 2: Den Build erstellen
FROM node:20-alpine AS builder
RUN npm install -g pnpm
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js sammelt anonyme Telemetriedaten während des Builds. 
# Deaktiviere dies hier, falls gewünscht:
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

CMD ["npm", "start"]
