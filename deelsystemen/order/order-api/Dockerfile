# Twee fasen: bouwen met Maven, draaien op een JRE. Beide tags vastgepind, nooit latest.
FROM maven:3.9.16-eclipse-temurin-21 AS build
WORKDIR /build
# Eerst alleen de pom, zodat de dependency-laag blijft staan als alleen de code wijzigt.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests
# Geen versienummer in het pad: dat staat in de pom en beweegt bij elke release.
RUN cp target/*.jar app.jar

FROM eclipse-temurin:21.0.11_10-jre-alpine
# Non-root: de container heeft geen enkele reden om als root te draaien.
RUN addgroup -S cbt && adduser -S -G cbt cbt
USER cbt
WORKDIR /app
COPY --from=build /build/app.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
