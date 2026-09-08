FROM docker.io/library/eclipse-temurin:17-jre

EXPOSE 8080

RUN mkdir /usr/app

COPY build/libs/build-tools-exercises-1.0-SNAPSHOT.jar /usr/app/
WORKDIR /usr/app

CMD ["java", "-jar", "build-tools-exercises-1.0-SNAPSHOT.jar"]
