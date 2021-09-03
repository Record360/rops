# rops 
The Record360 Operations tool

## Usage

### Installation

Add `rops` to your Gemfile and then run `bundle install`.

```ruby
# Gemfile
group :development do
  gem 'rops', github: 'Record360/rops'
end
```

### Operation

`rops` uses the current directory as the project root, with the directory name as the Docker image name, and looks for Kubernetes object configurations in a context-specific directory under `./platform` (e.g. `./platform/staging`).  It recognizes any Kubernetes object with an `image` tag that matches the Docker repository and image name without a version tag (e.g. `image: r360/web`), which is usually a `deployment`, `statefulSet`, or `cronJob`.

### Defaults

* Git repository: (current directory)
* Docker repository: `r360`
* Kubernetes context: `staging`
* Git branch: `master`

## Commands

### Status

Arguments: 
* `context`: Kubernetes context (default `staging`)

Displays the statuses of all deployable Kubernetes objects, including image version and number of pods running/desired. 

```shell
$ rops status
Currently running (staging):
  * gfc50028b web-archive-media-files (cronjob)
  * gfc50028b web-company-report (cronjob)
  * gfc50028b web-subscriptions (cronjob)
  * gfc50028b web-sync-billing (cronjob)
  * gfc50028b jobs [1/1] (deployment)
  * gfc50028b web-tsd [1/1] (deployment)
  * gfc50028b web [1/1] (deployment)
```

### Build

Arguments: 
* `commit`: Git commit/branch (default `master`)

Builds the Docker image, optionally specifying a Git branch name.  By default, it uses one less than the total number of CPU cores, although you can override this by setting `R360_BUILD_CORES`.  

```shell
$ rops build some-branch
Building image web:gfc50028b-some-branch using 7 cores ...
...
STEP 15/16: ARG GIT_VERSION
--> 69cfcafa4c3
STEP 16/16: ENV GIT_VERSION=$GIT_VERSION
COMMIT web:gfc50028b-rops
--> 8c5ea56990b
Successfully tagged localhost/web:gfc50028b-some-branch
8c5ea56990bfb1329b8180e4826fca7c5fb08d14d2097e9a05e29296c669cc86
```

### Push

Arguments: 
* `commit`: Git commit/branch (default `master`)

Pushes the Docker image to the repository, building if necessary.  

```shell
$ rops push some-branch
Local image web:gfc50028b-some-branch already exists
...
Writing manifest to image destination
Storing signatures
```

### Deploy

Arguments: 
* `commit`: Git commit/branch (default `master`)
* `context`: Kubernetes context (default `staging`)

Deploys the Docker image to Kubernetes, building and pushing if necessary.  Displays the currently running versions (like `status`), and any changes to the Kubernetes object configuration, and prompts for confirmation.  `commit` must be specified if `context` is `production`.  

```shell
$ rops deploy
Currently running (staging):
  * gfc50028b web-archive-media-files (cronjob)
  * gfc50028b web-company-report (cronjob)
  * gfc50028b web-subscriptions (cronjob)
  * gfc50028b web-sync-billing (cronjob)
  * gfc50028b jobs [1/1] (deployment)
  * gfc50028b web-tsd [1/1] (deployment)
  * gfc50028b web [1/1] (deployment)

Configuration changes:
  web (deployment)
    - spec.template.spec.containers[0].imagePullPolicy: "Always"

Deploy g12345678 (master) to staging? (y/N): y

deployment.apps/web configured
deployment.apps/jobs configured
cronjob.batch/web-archive-media-files configured
cronjob.batch/web-company-report configured
cronjob.batch/web-subscriptions configured
cronjob.batch/web-sync-billing configured
```
