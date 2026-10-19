# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for retrocession-domain. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the domain listens on 8094.
#
# Build context: repos/eia-retrocession-domain
#   docker build -f repos/eia-ops/images/verticals/retrocession-domain.Dockerfile -t eia/retrocession-domain:local repos/eia-retrocession-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-retrocession-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8094
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
