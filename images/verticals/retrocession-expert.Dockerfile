# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for retrocession-expert. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the expert listens on 8093.
#
# Build context: repos/eia-retrocession-expert
#   docker build -f repos/eia-ops/images/verticals/retrocession-expert.Dockerfile -t eia/retrocession-expert:local repos/eia-retrocession-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-retrocession-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8093
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
