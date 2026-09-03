# College Shell (Angular SSR) Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

RUN npm ci --legacy-peer-deps

COPY apps/college-shell ./apps/college-shell

RUN npx nx build college-shell --configuration=production

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/dist/apps/college-shell ./dist/apps/college-shell
COPY --from=builder /app/package*.json ./

RUN npm ci --omit=dev --legacy-peer-deps && npm cache clean --force

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

ENV PORT=4200

EXPOSE 4200

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:4200', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "dist/apps/college-shell/server/server.mjs"]
