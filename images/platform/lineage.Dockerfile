# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for lineage. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the service listens on 8101.
#
# Build context: repos/eia-platform/lineage
#   docker build -f repos/eia-ops/images/platform/lineage.Dockerfile -t eia/lineage:local repos/eia-platform/lineage
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/lineage-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8101
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
