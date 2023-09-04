FROM alpine:latest

RUN apk add --no-cache \
  ca-certificates \
  build-base \
  git \
  hare;