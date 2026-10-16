# Stage 1: Build the JAR with Maven & Java 21
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app

# Copy maven wrapper and pom.xml
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B || true

# Copy source code and build executable jar
COPY src/ ./src/
RUN ./mvnw clean package -DskipTests

# Stage 2: Minimal runtime image with Java 21 JRE
FROM eclipse-temurin:21-jre
WORKDIR /app

# Copy the built jar file
COPY --from=builder /app/target/*.jar app.jar

# Expose the server port
EXPOSE 8081

# Optimize JVM memory flags for Render free tier (512MB RAM)
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-Xmx380m", "-Xms150m", "-jar", "app.jar"]
