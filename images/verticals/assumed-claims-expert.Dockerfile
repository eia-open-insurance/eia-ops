# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for assumed-claims-expert. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the expert listens on 8089.
#
# Build context: repos/eia-assumed-claims-expert
#   docker build -f repos/eia-ops/images/verticals/assumed-claims-expert.Dockerfile -t eia/assumed-claims-expert:local repos/eia-assumed-claims-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-assumed-claims-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8089
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
