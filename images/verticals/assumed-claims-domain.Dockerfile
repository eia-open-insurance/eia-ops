# syntax=docker/dockerfile:1
# Deployment-owned Dockerfile for assumed-claims-domain. The owning repository is not modified.
# The repository Dockerfile copies target/*.jar and EXPOSEs 8080; this Gradle build writes build/libs and the domain listens on 8090.
#
# Build context: repos/eia-assumed-claims-domain
#   docker build -f repos/eia-ops/images/verticals/assumed-claims-domain.Dockerfile -t eia/assumed-claims-domain:local repos/eia-assumed-claims-domain
FROM eclipse-temurin:22-jre

WORKDIR /app
COPY build/libs/eia-assumed-claims-domain-*-SNAPSHOT.jar /app/app.jar

EXPOSE 8090
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
