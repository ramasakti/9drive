FROM oven/bun:1-alpine AS base

WORKDIR /app

COPY package.json bun.lock ./
COPY prisma ./prisma

RUN bun install --frozen-lockfile

COPY tsconfig.json ./
COPY src ./src

RUN bun run build && bun run prisma:generate

EXPOSE 4000

CMD ["sh", "-c", "bun run db:migrate:deploy && bun run seed:google-config:docker && bun dist/server.js"]
