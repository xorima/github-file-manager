# Github-file-manager

This application is designed to manage the files inside your github repository from a source of truth repository.

A good usecase for this is if you want a standardised `TESTING.md` file across all you repos labeled `cookbook` you can put that file in a source repo and this script will open pull requests on any repository which does not conform to the standard.

## User Permissions

- It is recommended to use a github bot account when using this application
- You must ensure the account has permissions to create branches and pull requests directly on the repository, it will not try to fork.
- You must also supply a GITHUB_TOKEN to access the github api server with.

## Items of Note

Github has a rate limiter, do not run this script continously you will get rate limited and then the script will fail
