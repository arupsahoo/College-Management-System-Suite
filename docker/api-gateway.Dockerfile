# API Gateway Dockerfile
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

RUN npm ci --legacy-peer-deps

COPY services/api-gateway ./services/api-gateway

RUN npx nx build api-gateway --configuration=production

FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/services/api-gateway/dist ./

COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev --legacy-peer-deps && npm cache clean --force

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "main.js"]
