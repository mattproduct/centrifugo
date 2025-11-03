# Build stage
FROM golang:1.25-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o centrifugo .

# Runtime stage
FROM alpine:3.21

ARG USER=centrifugo
ARG UID=1000
ARG GID=1000

RUN addgroup -S -g $GID $USER && \
    adduser -S -G $USER -u $UID $USER

RUN apk --no-cache upgrade && \
    apk --no-cache add ca-certificates && \
    update-ca-certificates

USER $USER

WORKDIR /centrifugo

# Copy binary from builder
COPY --from=builder --chown=$USER:$USER /build/centrifugo /usr/local/bin/centrifugo

# Listen on port 8080 for DigitalOcean App Platform health checks
# Enable WebSocket, API, Health, and Admin endpoints via environment variables
ENV CENTRIFUGO_HTTP_SERVER_PORT=8080 \
    CENTRIFUGO_ADMIN_ENABLED=true \
    CENTRIFUGO_ADMIN_EXTERNAL=true \
    CENTRIFUGO_HEALTH_ENABLED=true

CMD ["centrifugo"]
