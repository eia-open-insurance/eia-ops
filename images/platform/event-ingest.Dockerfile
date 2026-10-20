# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for event-ingest. The owning module's Gradle build
# writes build/libs/event-ingest-*-SNAPSHOT.jar and the service listens on 8102.
#
# Build context: repos/eia-platform/event-ingest
#   docker build -f repos/eia-ops/images/platform/event-ingest.Dockerfile -t eia/event-ingest:local repos/eia-platform/event-ingest
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/event-ingest-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8102
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
