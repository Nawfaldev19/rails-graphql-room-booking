# Stage 1: build the web app with Node.
FROM node:20-slim AS web
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY index.html tsconfig.json vite.config.ts schema.graphql ./
COPY public ./public
COPY src/web ./src/web
RUN npm run build

# Stage 2: the Rails app, with the built web app in its public folder.
FROM ruby:3.3-slim
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT=1 \
    PORT=3400
WORKDIR /app
RUN apt-get update -qq \
  && apt-get install --no-install-recommends -y build-essential libyaml-dev pkg-config \
  && rm -rf /var/lib/apt/lists/*
COPY src/api/Gemfile src/api/Gemfile.lock src/api/.ruby-version ./
RUN bundle install
COPY src/api ./
COPY --from=web /app/src/api/public ./public
RUN useradd --create-home room_booking && chown -R room_booking:room_booking /app
USER room_booking
EXPOSE 3400
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
  CMD ruby -e "require 'net/http'; exit(Net::HTTP.get_response(URI('http://localhost:3400/healthz')).code == '200' ? 0 : 1)"
CMD ["bin/container-start"]
