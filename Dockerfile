# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.5
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y curl libpq5 libvips tzdata && rm -rf /var/lib/apt/lists/*
ENV BUNDLE_PATH=/usr/local/bundle BUNDLE_FROZEN=true

FROM base AS dependencies
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.15 --no-document

# Includes development/test gems so the same repository can be verified in Docker.
FROM dependencies AS test
RUN bundle install
COPY . .
ENV RAILS_ENV=test
CMD ["./bin/rails", "test"]

FROM dependencies AS build
ENV RAILS_ENV=production BUNDLE_WITHOUT=development:test
RUN bundle install && rm -rf /usr/local/bundle/cache
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base AS production
ENV RAILS_ENV=production BUNDLE_WITHOUT=development:test
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
RUN groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails && mkdir -p tmp/pids log storage public/uploads && chown -R rails:rails tmp log storage public/uploads && chmod +x bin/docker-entrypoint
USER rails:rails
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 CMD curl --fail --silent http://127.0.0.1:3000/up || exit 1
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
