# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for contract-domain. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the domain listens on 8086.
#
# Build context: repos/eia-contract-domain
#   docker build -f repos/eia-ops/images/verticals/contract-domain.Dockerfile -t eia/contract-domain:local repos/eia-contract-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-contract-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8086
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
