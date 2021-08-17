# Github-file-manager

This application is designed to manage the files inside your github repository from a source of truth repository.

A good usecase for this is if you want a standardised `TESTING.md` file across all you repos labeled `cookbook` you can put that file in a source repo and this script will open pull requests on any repository which does not conform to the standard.

## User Permissions

- It is recommended to use a github bot account when using this application
- You must ensure the account has permissions to create branches and pull requests directly on the repository, it will not try to fork.
- You must also supply a GITHUB_TOKEN to access the github api server with.

## Items of Note

Github has a rate limiter, do not run this script continously you will get rate limited and then the script will fail

## Configuration

Below are a list of variables, what they mean and example values

| Name | Type | Required | Description |
|------|------|----------|-------------|
| GITHUB_TOKEN | `String` | Yes | Token to access the github api with, see [Creating a token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line) |
| GITHUB_API_ROOT | `String` | No | Where the api root is for github, defaults to api.github.com (Useful for enterprise users) |
| GFM_SOURCE_REPO_OWNER | `String` | Yes | The Owner of the repository whoch holds the standardised files |
| GFM_SOURCE_REPO_NAME | `String` | Yes | The name of the repository which holds the standardised files |
| GFM_SOURCE_REPO_PATH | `String` | Yes | The folder inside the Source Repo to find the files you wish to have standardised |
| GFM_DESTINATION_REPO_OWNER | `String` | Yes | The owner of the destination repositories you wish to update |
| GFM_DESTINATION_REPO_TOPICS | `String` | Yes | The topics that the destination repositories are tagged with to search for, Takes a csv, eg: `chef-cookbook,vscode`
| GFM_BRANCH_NAME | `String` | Yes | The name of the branch to create if changes are required |
| GFM_PULL_REQUEST_TITLE | `String` | Yes | The title to apply to the Pull Request |
| GFM_PULL_REQUEST_BODY | `String` | Yes | The body text to apply to the Pull Request |
| GFM_PULL_REQUEST_LABELS | `String` | No | The labels to apply to the Pull Request, Takes a csv, eg: `tech-debt,automated` |
| GFM_GIT_NAME | `String` | No | The Name to use when creating the git commits |
| GFM_GIT_EMAIL | `String` | No | The E-mail address to use when creating the git commits |
| GFM_CHANGELOG_LOCATION | `String` | No | The location of the change log to update relative to the root of the repo |
| GFM_CHANGELOG_MARKER | `String` | No | The string to use as the update point in the changelog, if not found it will be added before the next subtitle of `##` |
| GFM_MANAGE_CHANGELOG | `String` | Yes | Should we be managing the changelog, set to `0` for no, `1` for yes |

| GFM_DEFAULT_GIT_BRANCH | `String` | No | The name of the default branch, if not set this will default to `main` |

## Git Authentication

We use the `GITHUB_TOKEN` environment variable to also authenticate against git, github allows this to be used instead of username and password

## Docker Tags

Images are stored in <https://hub.docker.com/r/xorima/github-file-manager>

This application is tagged as follows

| Name | Description |
|------|-------------|
| latest | The latest mainline merge |
| dev  | The latest Pull Request build |
| semvar (eg: 1.0.0) | A Github Release of a fixed point in time |

While all updates should result in a release this is not always the case, sometimes mainline will change for non-functional related changes and a release will not be made, eg a new file in the `infrastructure` folder
