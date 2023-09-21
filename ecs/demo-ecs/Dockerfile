FROM adoptopenjdk:11-jre-hotspot as builder
ARG JAR_FILE=build/libs/*.jar
COPY ${JAR_FILE} application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM adoptopenjdk:11-jre-hotspot

RUN set -o errexit -o nounset \
    && echo "Adding spring user and group....." \
    && groupadd --system spring \
    && useradd --system --gid spring --shell /bin/bash --create-home spring \
    && chown --recursive spring:spring /home/spring

WORKDIR /home/spring

USER spring:spring

COPY --from=builder dependencies/ ./
COPY --from=builder snapshot-dependencies/ ./
COPY --from=builder spring-boot-loader/ ./
COPY --from=builder application/ ./

EXPOSE 8080

ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
