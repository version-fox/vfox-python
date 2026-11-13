# Copyright 2026 Han Li and contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN set -o errexit -o nounset -o xtrace; \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        ca-certificates \
        curl \
        tar \
        xz-utils \
        zip; \
    rm -rf /var/lib/apt/lists/*

ARG VFOX_VERSION=1.1.0
ARG VFOX_SHA256=3b33c3c468b27bc17aecf0d6d3af24fe49fe204972984904a136a47b402a0ee4

RUN set -o errexit -o nounset -o xtrace; \
    curl --fail --silent --show-error --location \
        --output /tmp/vfox.tar.gz \
        "https://github.com/version-fox/vfox/releases/download/v${VFOX_VERSION}/vfox_${VFOX_VERSION}_linux_x86_64.tar.gz"; \
    echo "${VFOX_SHA256}  /tmp/vfox.tar.gz" | sha256sum --check; \
    mkdir /opt/vfox; \
    tar --extract --gzip --file /tmp/vfox.tar.gz \
        --directory /opt/vfox --strip-components=1; \
    rm /tmp/vfox.tar.gz; \
    ln -s /opt/vfox/vfox /usr/local/bin/vfox; \
    vfox --version

# The Go test drives every scenario through exec calls; the container only
# has to stay alive.
CMD ["sleep", "infinity"]
