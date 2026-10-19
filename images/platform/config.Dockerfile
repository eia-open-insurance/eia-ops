# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for config. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the service listens on 8888.
#
# Build context: repos/eia-platform/config
#   docker build -f repos/eia-ops/images/platform/config.Dockerfile -t eia/config:local repos/eia-platform/config
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/config-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8888
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
