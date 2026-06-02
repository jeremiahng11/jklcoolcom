# Multi-stage build for the Coolify Companion push server.
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm install --omit=dev
COPY --from=build /app/dist ./dist
# Persist tokens/state here — mount a volume at /app/data in production.
ENV DATA_DIR=/app/data
EXPOSE 8090
CMD ["node", "dist/index.js"]
