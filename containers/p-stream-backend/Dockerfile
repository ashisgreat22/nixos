FROM node:22-alpine

WORKDIR /app

# Install git and openssl (needed for Prisma)
RUN apk add --no-cache git openssl

# Clone repository
RUN git clone https://github.com/p-stream/backend .

# Install dependencies (use npm install since upstream lockfile can be out of sync)
RUN npm install

# We do NOT run build here because we need ENV vars at build time? 
# The original Dockerfile used ARGs. We can do that or just build at runtime if we want dynamic config.
# But for stability, let's follow their pattern but use defaults.
# We will use ENV at runtime to override.

# Prisma generate needs DATABASE_URL format (doesn't need actual connectivity)
ENV DATABASE_URL=postgresql://dummy:dummy@localhost:5432/dummy
RUN npx prisma generate
RUN npm run build

EXPOSE 3000

# We need a custom entrypoint to handle DB migrations
CMD ["sh", "-c", "npx prisma migrate deploy && node .output/server/index.mjs"]
