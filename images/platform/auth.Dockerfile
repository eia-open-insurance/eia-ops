# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for auth. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the service listens on 9000.
#
# Build context: repos/eia-platform/auth
#   docker build -f repos/eia-ops/images/platform/auth.Dockerfile -t eia/auth:local repos/eia-platform/auth
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/auth-*-SNAPSHOT.jar /app/app.jar

EXPOSE 9000
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
