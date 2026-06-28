# =========================================================================
# METHOD 1: MULTI-STAGE DOCKER BUILD (Compiles Flutter Web inside Docker)
# Good for CI/CD systems, but heavy to build locally.
# =========================================================================
FROM debian:stable-slim AS build-env

# Install dependencies
RUN apt-get update && apt-get install -y \
  curl \
  git \
  unzip \
  xz-utils \
  zip \
  libglu1-mesa \
  && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Check environment & enable web build
RUN flutter doctor
RUN flutter config --enable-web

# Build application
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve the compiled app with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


# =========================================================================
# METHOD 2: ULTRA-LIGHTWEIGHT VPS BUILD (Copy local build - RECOMMENDED FOR LOW RAM VPS)
# To use this method, run `flutter build web --release` on your local machine,
# and replace this file content with:
#
# FROM nginx:alpine
# COPY build/web /usr/share/nginx/html
# EXPOSE 80
# CMD ["nginx", "-g", "daemon off;"]
# =========================================================================
