FROM elixir:1.15-alpine AS builder

RUN apk add --no-cache gcc g++ make musl-dev git

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config
COPY lib lib
COPY priv priv
RUN mix compile
RUN mix release

FROM alpine:3.18 AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/fun_chat ./

ENV PHX_HOST=localhost
ENV PORT=4000
ENV MIX_ENV=prod

EXPOSE 4000
CMD ["bin/fun_chat", "start"]
