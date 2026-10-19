# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for document-expert. The owning repository is not modified.
# The repository Dockerfile uses build/libs/*.jar, which matches both the boot jar and the -plain.jar produced by Gradle and makes COPY fail; this Dockerfile pins the boot jar and exposes 8095.
#
# Build context: repos/eia-document-expert
#   docker build -f repos/eia-ops/images/verticals/document-expert.Dockerfile -t eia/document-expert:local repos/eia-document-expert
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-document-expert-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8095
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
