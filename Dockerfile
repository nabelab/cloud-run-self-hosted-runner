FROM debian:bookworm

ARG RUNNER_VERSION="2.325.0"
ARG RUNNER_SHA256="5020da7139d85c776059f351e0de8fdec753affc9c558e892472d43ebeb518f4"

RUN apt-get update \
  && apt-get install -y \
  curl \
  perl \
  libkrb5-3 \
  zlib1g \
  liblttng-ust1 \
  libssl3 \
  libicu72 \
  jq \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd -g 61000 runner \
  && useradd -g 61000 -u 61000 -l -m -s /bin/false runner

WORKDIR /home/runner

RUN curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
  && echo "${RUNNER_SHA256}  actions-runner.tar.gz" | shasum -a 256 -c \
  && tar xzf actions-runner.tar.gz \
  && rm -f actions-runner.tar.gz \
  && chown -R runner:runner /home/runner

USER runner

COPY --chmod=0755 entrypoint.sh .

ENTRYPOINT ["./entrypoint.sh"]
