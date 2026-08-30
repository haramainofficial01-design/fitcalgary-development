FROM golang:1.27-alpine AS build
WORKDIR /src/services/api-go
COPY services/api-go/go.mod services/api-go/go.sum ./
RUN go mod download
COPY services/api-go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/fitcalgary-api ./cmd/api

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/fitcalgary-api /app/fitcalgary-api
COPY services/api/migrations /app/migrations
ENV MIGRATIONS_DIR=/app/migrations
EXPOSE 4000
USER nonroot:nonroot
ENTRYPOINT ["/app/fitcalgary-api"]
