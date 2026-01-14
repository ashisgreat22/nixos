# Based on the official Dockerfile but modified for self-building
FROM node:20-alpine as build
WORKDIR /app
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

# Install git to clone the repo
RUN apk add --no-cache git

# Clone the repository
# We clone main branch. To pin a version, we could checkout a specific hash.
RUN git clone https://github.com/p-stream/p-stream .

# Install dependencies
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

# Build Arguments
# These determine the features enabled in the static build.
ARG TMDB_READ_API_KEY=""
ARG CORS_PROXY_URL=""
ARG BACKEND_URL=""
ARG PWA_ENABLED="true"
ARG OPENSEARCH_ENABLED="false"
# Enable onboarding so the user can potentially configure things in UI (if supported)
# or at least not crash without a key (though TMDB key is usually required for content).
ARG HAS_ONBOARDING="true"
ARG ALLOW_FEBBOX_KEY="true"

# Set Env vars for Vite
ENV VITE_PWA_ENABLED=${PWA_ENABLED}
ENV VITE_OPENSEARCH_ENABLED=${OPENSEARCH_ENABLED}
ENV VITE_TMDB_READ_API_KEY=${TMDB_READ_API_KEY}
ENV VITE_CORS_PROXY_URL=${CORS_PROXY_URL}
ENV VITE_BACKEND_URL=${BACKEND_URL}
ENV VITE_HAS_ONBOARDING=${HAS_ONBOARDING}
ENV VITE_ALLOW_FEBBOX_KEY=${ALLOW_FEBBOX_KEY}

# Build the app
RUN pnpm run build

# Production environment
FROM nginx:stable-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
