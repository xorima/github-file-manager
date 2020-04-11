FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04

COPY app /app
RUN apt-get update && apt-get install -y git

ENTRYPOINT ["pwsh", "-file", "app/entrypoint.ps1"]