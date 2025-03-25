# Stage 1: Download the JAR file from JFrog Artifactory
# Use an Alpine Linux base image
FROM alpine:latest as downloader

# Install curl (if not already installed)
RUN apk update && apk add --no-cache curl xmlstarlet

# Set your Artifactory details... Passed as build arguments
ARG ARTIFACTORY_USERNAME
ARG ARTIFACTORY_REFERENCE_TOKEN
ARG ARTIFACTORY_URL

# Set the artifact details
ARG ARTIFACT_REPO
ARG ARTIFACT_NAME="nextconnect-userhub"
ARG ARTIFACT_PATH="com/merck/nextconnect/nextconnect-userhub/0.0.3-SNAPSHOT"

# Retrieve the latest version using Artifactory API
RUN set -x \
    && export MAVEN_METADATA=$(curl -u $ARTIFACTORY_USERNAME:$ARTIFACTORY_REFERENCE_TOKEN -s "$ARTIFACTORY_URL/$ARTIFACT_REPO/$ARTIFACT_PATH/maven-metadata.xml") \
    && VERSION=$(echo "$MAVEN_METADATA" | xmlstarlet sel -t -m '//snapshotVersion[1]/value' -v . -n) \
	&& echo "Version extracted: $VERSION" \
    && curl -L -o /tmp/app.jar -u $ARTIFACTORY_USERNAME:$ARTIFACTORY_REFERENCE_TOKEN "$ARTIFACTORY_URL/$ARTIFACT_REPO/$ARTIFACT_PATH/$ARTIFACT_NAME-$VERSION.jar"

  
# Stage 2: Build image using the downloaded jar
FROM openjdk:21-jdk-slim
USER root
ENV LANG C.UTF-8
RUN apt-get update && apt-get install -y bash curl sudo && rm -rf /var/lib/apt/lists/*

# Copy the JAR file from the downloader stage
COPY --from=downloader /tmp/app.jar svc.jar

RUN adduser --disabled-password --gecos '' userhub && usermod -aG sudo userhub && echo "userhub ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN chmod 777 /svc.jar
USER userhub
EXPOSE 8080 25 20 9888 9889 9997 9999
CMD ["/bin/bash"]
