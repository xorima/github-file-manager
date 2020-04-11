FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04

LABEL maintainer="Xorima"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="xorima/github-file-manager"
LABEL org.label-schema.description="A File Manager system for Github Repositories"
LABEL org.label-schema.url="https://github.com/Xorima/github-file-manager"
LABEL org.label-schema.vcs-url="https://github.com/Xorima/github-file-manager"

COPY app /app
RUN apt-get update && apt-get install -y git

ENTRYPOINT ["pwsh", "-file", "app/entrypoint.ps1"]