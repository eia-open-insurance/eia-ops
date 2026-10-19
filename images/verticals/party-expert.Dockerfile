# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for party-expert. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the expert listens on 8081.
#
# Build context: repos/eia-party-expert
#   docker build -f repos/eia-ops/images/verticals/party-expert.Dockerfile -t eia/party-expert:local repos/eia-party-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-party-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8081
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
