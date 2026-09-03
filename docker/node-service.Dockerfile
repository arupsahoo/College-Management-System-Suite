# Node microservice Dockerfile template
# Build with: docker build -f docker/node-service.Dockerfile --build-arg SERVICE_NAME=auth-service --build-arg SERVICE_PORT=3001 .

ARG SERVICE_NAME
ARG SERVICE_PORT=3000

FROM node:20-alpine AS builder

ARG SERVICE_NAME

WORKDIR /app

COPY package*.json ./
COPY nx.json ./
COPY tsconfig.base.json ./

RUN npm ci --legacy-peer-deps

COPY services/${SERVICE_NAME} ./services/${SERVICE_NAME}

RUN npx nx build ${SERVICE_NAME} --configuration=production

FROM node:20-alpine

ARG SERVICE_NAME
ARG SERVICE_PORT

WORKDIR /app

COPY --from=builder /app/services/${SERVICE_NAME}/dist ./

COPY --from=builder /app/package*.json ./
RUN npm ci --omit=dev --legacy-peer-deps && npm cache clean --force

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

EXPOSE ${SERVICE_PORT}

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:${SERVICE_PORT}/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "main.js"]
