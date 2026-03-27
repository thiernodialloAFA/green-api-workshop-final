FROM maven:3.8.3-openjdk-17 AS build
WORKDIR /app
COPY pom.xml .
# Cache Maven dependencies
RUN mvn dependency:go-offline -q || true
COPY src ./src
RUN mvn -q package -DskipTests

FROM maven:3.8.3-openjdk-17
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-XX:+ExitOnOutOfMemoryError", "-Xms512m", "-Xmx1536m", "-jar", "app.jar"]

