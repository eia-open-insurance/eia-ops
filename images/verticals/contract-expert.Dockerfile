# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for contract-expert. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the expert listens on 8085.
#
# Build context: repos/eia-contract-expert
#   docker build -f repos/eia-ops/images/verticals/contract-expert.Dockerfile -t eia/contract-expert:local repos/eia-contract-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-contract-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8085
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
