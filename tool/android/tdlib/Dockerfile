FROM --platform=linux/amd64 ubuntu@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90 AS build

RUN --mount=type=secret,id=ca_bundle,required=false \
    set -eu; \
    ca_option=""; \
    if [ -f /run/secrets/ca_bundle ]; then \
        sed -i 's#http://#https://#g' /etc/apt/sources.list.d/ubuntu.sources; \
        cp /run/secrets/ca_bundle /tmp/local-ca-bundle.crt; \
        chmod 0644 /tmp/local-ca-bundle.crt; \
        ca_option="-o Acquire::https::CaInfo=/tmp/local-ca-bundle.crt"; \
    fi; \
    apt-get ${ca_option} update; \
    DEBIAN_FRONTEND=noninteractive apt-get ${ca_option} install -yq \
        ca-certificates default-jdk g++ git gperf make perl php-cli unzip wget; \
    if [ -f /run/secrets/ca_bundle ]; then \
        cp /tmp/local-ca-bundle.crt /usr/local/share/ca-certificates/local-build-network.crt; \
        update-ca-certificates; \
    fi; \
    rm -rf /var/lib/apt/lists/*

ARG TDLIB_COMMIT=022d60202e446ad1287b9fb68e687c8a0760788b
ARG OPENSSL_COMMIT=8cf17aaeb4599f8af87fefd810b5b5fee90fe69e
ARG ANDROID_NDK_VERSION=28.2.13676358
ARG ANDROID_CMAKE_VERSION=3.22.1
ARG ANDROID_COMMAND_LINE_TOOLS=13114758
ARG ANDROID_COMMAND_LINE_TOOLS_SHA256=7ec965280a073311c339e571cd5de778b9975026cfcbe79f2b1cdcb1e15317ee

WORKDIR /home

RUN mkdir -p SDK/cmdline-tools \
    && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_COMMAND_LINE_TOOLS}_latest.zip" \
        -O commandlinetools.zip \
    && echo "${ANDROID_COMMAND_LINE_TOOLS_SHA256}  commandlinetools.zip" | sha256sum -c - \
    && unzip -q commandlinetools.zip -d SDK/cmdline-tools \
    && rm commandlinetools.zip \
    && mv SDK/cmdline-tools/cmdline-tools SDK/cmdline-tools/latest \
    && yes | SDK/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null \
    && SDK/cmdline-tools/latest/bin/sdkmanager --install \
        "ndk;${ANDROID_NDK_VERSION}" \
        "cmake;${ANDROID_CMAKE_VERSION}" \
        "build-tools;34.0.0" \
        "platforms;android-34" >/dev/null

RUN git init td \
    && git -C td remote add origin https://github.com/tdlib/td.git \
    && git -C td fetch --depth 1 origin "${TDLIB_COMMIT}" \
    && git -C td checkout --detach FETCH_HEAD \
    && test "$(git -C td rev-parse HEAD)" = "${TDLIB_COMMIT}"

# TDLib's official Android script accepts a source label. Point it at the exact
# OpenSSL commit rather than a mutable tag while preserving the upstream build.
RUN sed -i \
        's#archive/refs/tags/\$OPENSSL_VERSION.tar.gz#archive/\$OPENSSL_VERSION.tar.gz#' \
        td/example/android/build-openssl.sh \
    && sed -i \
        's/for ABI in arm64-v8a armeabi-v7a x86_64 x86 ; do/for ABI in arm64-v8a x86_64 ; do/' \
        td/example/android/build-openssl.sh td/example/android/build-tdlib.sh \
    && ! grep -q 'archive/refs/tags' td/example/android/build-openssl.sh \
    && ! grep -q 'for ABI in .*armeabi-v7a' \
        td/example/android/build-openssl.sh td/example/android/build-tdlib.sh \
    && cd td/example/android \
    && ./build-openssl.sh \
        /home/SDK "${ANDROID_NDK_VERSION}" /home/openssl "${OPENSSL_COMMIT}" \
    && ./build-tdlib.sh \
        /home/SDK "${ANDROID_NDK_VERSION}" /home/openssl c++_static JSON

RUN mkdir -p /output/libs \
    && cp -a td/example/android/tdlib/libs/. /output/libs/ \
    && { \
        echo "tdlib_commit=${TDLIB_COMMIT}"; \
        echo "tdlib_version=1.8.66"; \
        echo "openssl_version=3.5.7 LTS"; \
        echo "openssl_commit=${OPENSSL_COMMIT}"; \
        echo "android_ndk=${ANDROID_NDK_VERSION}"; \
        echo "cmake=${ANDROID_CMAKE_VERSION}"; \
        echo "android_command_line_tools=${ANDROID_COMMAND_LINE_TOOLS}"; \
        echo "android_command_line_tools_sha256=${ANDROID_COMMAND_LINE_TOOLS_SHA256}"; \
        echo "native_android_sdk_platform=34"; \
        echo "native_android_build_tools=34.0.0"; \
        echo "android_stl=c++_static"; \
        echo "tdlib_interface=JSON"; \
        echo "cmake_build_type=RelWithDebInfo"; \
        echo "android_platform_requested=android-16"; \
        echo "android_platform_effective_64_bit=android-21"; \
        echo "abis=arm64-v8a,x86_64"; \
        echo "base_image=ubuntu@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90"; \
        /home/SDK/ndk/${ANDROID_NDK_VERSION}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang \
            --version | head -n 1 | sed 's/^/clang=/' ; \
        /home/SDK/cmake/${ANDROID_CMAKE_VERSION}/bin/cmake \
            --version | head -n 1 | sed 's/^/cmake_runtime=/' ; \
        dpkg-query -W -f='package=${Package} version=${Version}\n' \
            default-jdk g++ git gperf make perl php-cli unzip wget; \
    } > /output/build-toolchain.txt \
    && cd /output \
    && find libs -type f -name '*.so' -print0 \
        | sort -z \
        | xargs -0 sha256sum > SHA256SUMS

FROM scratch
COPY --from=build /output/ /
