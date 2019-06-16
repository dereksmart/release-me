# release-me
![](https://media1.tenor.com/images/76d80859804520e02392747222298ac4/tenor.gif?itemid=10533470)

Script that hopefully help in managing and shipping WordPress plugin releases on GitHub and SVN.

Get started with `./release-me`

# Release branch management
This script is designed to help keep your release branches stay in order. Typically used to kick off a code freeze and start the beta cycle.

## Options

| Options                       | Description                                     |
|-------------------------------|-------------------------------------------------|
| `-h` or `--help`              | Shows help message                              |
| `-v` or `--version`           | Shows script version                            |
| `-n` or `--new`               | Start a new release branch                      |
| `-u` or `--update`            | Update existing release branch                  |
| `-r` or `--release`           | The release number you are branching            |
| `-p` or `--plugin-slug`       | Plugin's slug                                   |
| `-o` or `--github-org`        | GitHub organization (default "Automattic")      |
| `-b` or `--branch`            | Build branch source (default `master`)          |
| `-c` or `--clean`             | Clean build directory                           |

## Customize the build.

This script will always respect the custom variables set in `.custom` above anything in the target plugin.

`.releaseignore`: A txt file that comprises of lines of file patterns to exclude from production release branches. Add file patterns to purge extra things from the release branch that is not defined in the plugin's `.releaseignore`.
 - This will be concatenated with the plugin's `.releaseignore` and/or `.svnignore` file if they are found.

`.custom`: A file containing many over-writable aspects of of the script, such as:
 - `BUILD_COMMAND`: A string to be `eval`'d during the script that will "build" the plugin. It defaults to `yarn build-production`.

## Example commands

Kick off a new beta release!
- `./release-me -n`

Create a new set of release branches for version 2.1.
- `./release-me -n -o="Automattic" -p="vaultpress" -r="2.1"`

Update the `2.2` release branch based on the branch `hotfix-branch`
- `./release-me -u -b="hotfix-branch" -r="2.2"`
