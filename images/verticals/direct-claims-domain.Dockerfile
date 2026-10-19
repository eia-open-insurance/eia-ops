# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for direct-claims-domain. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the domain listens on 8088.
#
# Build context: repos/eia-direct-claims-domain
#   docker build -f repos/eia-ops/images/verticals/direct-claims-domain.Dockerfile -t eia/direct-claims-domain:local repos/eia-direct-claims-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-direct-claims-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8088
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
