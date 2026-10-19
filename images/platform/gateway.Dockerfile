# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for gateway. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar; this Gradle build writes build/libs.
#
# Build context: repos/eia-platform/gateway
#   docker build -f repos/eia-ops/images/platform/gateway.Dockerfile -t eia/gateway:local repos/eia-platform/gateway
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/gateway-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8080
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
