# syntax=docker/dockerfile:1

FROM node:22-alpine AS deps
RUN apk add --no-cache libc6-compat openssl
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

FROM node:22-alpine AS builder
RUN apk add --no-cache openssl
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# NEXT_PUBLIC_* vars are inlined into the client bundle at build time, so they
# must be real values here (Hugging Face Space secrets are only injected at
# container *runtime*, not during `docker build`). The publishable key is
# meant to be public, so baking it in is safe — it is not a secret.
ENV NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_cmVmaW5lZC1jYWxmLTQyNzkuY2xlcmsuYWNjb3VudHMuZGV2JA
ENV NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
ENV NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
# Server-only secrets just need a syntactically valid placeholder here so
# `next build` doesn't crash constructing clients — the real values are
# provided as Space secrets and read at container runtime instead.
ENV DATABASE_URL="postgresql://user:pass@localhost:5432/db"
ENV CLERK_SECRET_KEY=sk_test_placeholder
RUN npx prisma generate
RUN npm run build

FROM node:22-alpine AS runner
RUN apk add --no-cache openssl
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=7860
ENV HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 7860

CMD ["node", "server.js"]
