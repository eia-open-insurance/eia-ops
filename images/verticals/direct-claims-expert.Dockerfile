# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for direct-claims-expert. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the expert listens on 8087.
#
# Build context: repos/eia-direct-claims-expert
#   docker build -f repos/eia-ops/images/verticals/direct-claims-expert.Dockerfile -t eia/direct-claims-expert:local repos/eia-direct-claims-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-direct-claims-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8087
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
