FROM node:22-slim AS swagger
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM ruby:3.2-slim
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without development test \
 && bundle install --jobs 4
COPY . .
COPY --from=swagger /app/node_modules ./node_modules
# Sinatra 4 only permits localhost Host headers outside production ("Host not permitted" 403 behind the ingress).
ENV APP_ENV=production
EXPOSE 4567
# ponytail: webrick (already in Gemfile) is enough for a low-traffic dev tool; switch to puma if load grows.
CMD ["bundle", "exec", "rackup", "-s", "webrick", "-o", "0.0.0.0", "-p", "4567", "config.ru"]
