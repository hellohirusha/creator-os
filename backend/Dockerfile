# ─── Build stage ─────────────────────────────────────────────
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy dependency files first (Docker layer caching — only re-downloads if go.mod changes)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary (CGO disabled for smaller binary, static linking)
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o /app/server \
    ./cmd/api

# ─── Final stage ─────────────────────────────────────────────
# Use minimal image — result is ~15MB instead of ~300MB
FROM alpine:3.18

# Add certificates (needed for HTTPS outbound requests)
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy only the binary from the build stage
COPY --from=builder /app/server .

# Railway sets PORT automatically — we use 8080 as default
EXPOSE 8080

# Run the server
CMD ["./server"]