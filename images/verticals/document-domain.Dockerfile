# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for document-domain. The owning repository is not modified.
# The repository Dockerfile uses build/libs/*.jar, which matches both the boot jar and the -plain.jar produced by Gradle and makes COPY fail; this Dockerfile pins the boot jar and exposes 8096.
#
# Build context: repos/eia-document-domain
#   docker build -f repos/eia-ops/images/verticals/document-domain.Dockerfile -t eia/document-domain:local repos/eia-document-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-document-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8096
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
