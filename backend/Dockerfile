FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY .m2/settings.xml /root/.m2/settings.xml
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN mkdir -p /app/uploads /app/cms
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
