# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for party-domain. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the domain listens on 8082.
#
# Build context: repos/eia-party-domain
#   docker build -f repos/eia-ops/images/verticals/party-domain.Dockerfile -t eia/party-domain:local repos/eia-party-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-party-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8082
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
