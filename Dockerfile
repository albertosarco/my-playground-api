#
# Build stage
#
FROM maven:3.9.6-eclipse-temurin-17-alpine@sha256:740d326713d9d56b69a82e49988cd6266b5329e046681c44790b4e0ae2360b56 AS build
COPY src /home/app/src
COPY pom.xml /home/app
RUN mvn -f /home/app/pom.xml clean package


# Build a custom Java runtime
FROM eclipse-temurin:17 AS jre-build

# Add the jar file to the container
COPY --from=build /home/app/target/my-playground-api.jar /app/app.jar

# Set the working directory
WORKDIR /app

# List jar modules
RUN jar xf app.jar
RUN jdeps \
    --ignore-missing-deps \
    --print-module-deps \
    --multi-release 17 \
    --recursive \
    --class-path 'BOOT-INF/lib/*' \
    app.jar > modules.txt

# Create a custom Java runtime
RUN $JAVA_HOME/bin/jlink \
         --add-modules $(cat modules.txt) \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /javaruntime

# Define your base image
FROM debian:buster-slim

# Define the Java home directory
ENV JAVA_HOME=/opt/java/openjdk

# Add the Java runtime to the path
ENV PATH "${JAVA_HOME}/bin:${PATH}"

# Copy the custom Java runtime to the container
COPY --from=jre-build /javaruntime $JAVA_HOME

# Continue with your application deployment
RUN mkdir /opt/server

# Add the jar file to the container
COPY --from=jre-build /app/app.jar /opt/server/

# Add a user to run our application so that it doesn't need to run as root
RUN addgroup --system usergroup && adduser --system user --ingroup usergroup

# Set the user to run our application
USER user

# Expose the port our application will run on
EXPOSE 8080

CMD ["java", "-jar", "/opt/server/app.jar"]