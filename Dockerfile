FROM node:20.16.0-alpine AS base

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN npm i -g pnpm

FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --force
RUN pnpm run -r build
RUN pnpm deploy --filter=server --prod /app --legacy
RUN pnpm deploy --filter=server --prod /app-sqlite --legacy

RUN cd /app && pnpm exec prisma generate

RUN cd /app-sqlite && \
    rm -rf ./prisma && \
        mv prisma-sqlite prisma && \
            pnpm exec prisma generate

            # MySQL版本（保留但不是默认）
            FROM base AS app-mysql
            COPY --from=build /app /app
            WORKDIR /app
            EXPOSE 4000

            ENV NODE_ENV=production
            ENV HOST="0.0.0.0"
            ENV SERVER_ORIGIN_URL=""
            ENV MAX_REQUEST_PER_MINUTE=60
            ENV AUTH_CODE=""
            ENV DATABASE_URL=""

            RUN chmod +x ./docker-bootstrap.sh
            CMD ["./docker-bootstrap.sh"]

            # SQLite版本（作为默认最后阶段）
            FROM base AS app-sqlite
            COPY --from=build /app-sqlite /app
            WORKDIR /app
            EXPOSE 4000

            ENV NODE_ENV=production
            ENV HOST="0.0.0.0"
            ENV SERVER_ORIGIN_URL=""
            ENV MAX_REQUEST_PER_MINUTE=60
            ENV AUTH_CODE=""
            ENV DATABASE_URL="file:../data/wewe-rss.db"
            ENV DATABASE_TYPE="sqlite"

            RUN chmod +x ./docker-bootstrap.sh
            CMD ["./docker-bootstrap.sh"]
