FROM ruby:3.2.0-alpine as Builder
ENV APP_HOME="/var/lib/truemail-rack" \
    TMP="/var/lib/truemail-rack/tmp"
RUN apk add --virtual build-dependencies git && \
    git clone https://github.com/truemail-rb/truemail-rack.git $TMP -q && \
    cd $TMP && git checkout v0.9.0 -q && \
    mv app config config.ru .ruby-version Gemfile* $APP_HOME && rm -rf $TMP && \
    apk del build-dependencies
WORKDIR $APP_HOME
RUN gem i bundler -v $(tail -1 Gemfile.lock | tr -d ' ')
RUN apk add --virtual build-dependencies make cmake g++ && \
    BUNDLE_FORCE_RUBY_PLATFORM=1 && \
    bundle check || bundle install --system --without=test development && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -regex ".*\.[coh]" -delete && \
    apk del build-dependencies

FROM ruby:3.2.0-alpine
ENV INFO="Truemail lightweight rack based web API 🚀" \
    APP_USER="truemail" \
    APP_HOME="/var/lib/truemail-rack" \
    APP_PORT="8080" \
    VERIFIER_EMAIL=sistema@alkc.com.br \
    ACCESS_TOKENS=a262d915-15bc-417c-afeb-842c63b54154,f44cd67e-aaa0-4e6c-aa6c-d52cf61f84ac \
    EMAIL_PATTERN="/\A.+@.+\z/" \
    SMTP_ERROR_BODY_PATTERN="/(?=.*550)(?=.*(user|account|customer|mailbox|something_else)).*/" \
    DNS=8.8.8.8,8.8.4.4:53 \
    NOT_RFC_MX_LOOKUP_FLOW=true \
    SMTP_PORT=2525 \
    SMTP_FAIL_FAST=true \
    SMTP_SAFE_CHECK=true \
    LOG_STDOUT=true
    LABEL description=$INFO
RUN apk add curl && \
    adduser -D $APP_USER
COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=Builder --chown=truemail:truemail $APP_HOME $APP_HOME
USER $APP_USER
WORKDIR $APP_HOME
EXPOSE $APP_PORT
CMD echo $INFO && thin -R config.ru -a 0.0.0.0 -p $APP_PORT -e production start
HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl -f echo "http://localhost:${APP_PORT}/healthcheck" || exit 1
