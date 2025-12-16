FROM openjdk:17.0.2-jdk

EXPOSE 8080

RUN mkdir /usr/app

COPY ./build/libs/ansible-exercises-*-SNAPSHOT.jar /usr/app/
WORKDIR /usr/app

CMD java -jar ansible-exercises-*.jar
