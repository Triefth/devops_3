# Etapa 1: Construcción con Maven
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
# Copia solo el pom para cachear dependencias
COPY pom.xml .
RUN mvn dependency:go-offline
# Copia el código fuente y compila
COPY src ./src
RUN mvn clean package -DskipTests

# Etapa 2: Imagen ligera de producción
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# Usuario no root (buena práctica)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /build/target/*.jar app.jar
COPY entrypoint.sh /entrypoint.sh
USER appuser
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]