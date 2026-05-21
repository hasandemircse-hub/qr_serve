# syntax=docker/dockerfile:1.7
# QuickServe Cloud — multi-stage build
# Build context: repo root

FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml ./
COPY common/pom.xml common/
COPY cloud/pom.xml cloud/
COPY edge/pom.xml edge/
RUN --mount=type=cache,target=/root/.m2 \
    mvn -pl cloud -am -DskipTests -q dependency:go-offline || true
COPY common common
COPY cloud cloud
RUN --mount=type=cache,target=/root/.m2 \
    mvn -pl cloud -am -DskipTests -q package
RUN cp cloud/target/cloud-*.jar /app.jar

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN addgroup --system app && adduser --system --ingroup app app
COPY --from=builder /app.jar /app/app.jar
USER app
EXPOSE 8080
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC"
ENV SPRING_PROFILES_ACTIVE=prod
ENTRYPOINT ["sh","-c","exec java $JAVA_OPTS -jar /app/app.jar"]
