# rops 

The Record360 Operations tool - checkout, build, deploy

## Usage

This tool implements the Record360 Best Practices for building and deploying projects.  It interfaces with Git (for source control), Docker/Podman (for container images), and Kubernetes (cluster deployments).

### Installation

Add `rops` to your Gemfile and then run `bundle install`.

```ruby
# Gemfile
group :development do
  gem 'rops', github: 'Record360/rops'
end
```

### Configuration

`rops` has several opinionated defaults, which can be overridden by command line options or a configuration file.

#### Project Root Directory
  By default, the current working directory when `rops` runs.  It can be overridden with the `--root=<DIR>` option.

  The project root directory must contain:
  * Git repository (`./`)
  * Dockerfile (`./Dockerfile`)
  * Kubernetes configuration files (`./platform/`)

  `rops` will search for an optional configuration file in:
  * `./.rops.yaml`
  * `./platform/rops.yaml`
  * `./config/rops.yaml`

#### Docker Container Images
  By default, a single image named from the the Project root directory and built from `./Dockerfile`.  May be overridden by setting the `images` array in the configuration file, e.g.:

```yaml
images:
- name: 'first-image'
  dockerfile: dockerfiles/first.Dockerfile
- name: 'second-image'
  dockerfile: dockerfiles/second.Dockerfile
```

#### Git Default Branch
  The Git branch to build, by default `master`.  Overridden with the `default_branch` field in the configuration file.

#### Docker Registry
  The Docker registry to push container images.  By default, `docker.io/r360`, which is probably not what you want and should be overridden by setting the `registry` field in the configuration file.

#### Kubernetes Context
  The name of the Kubernetes context to deploy to (as listed in `~/.kube/config`).  Defaults to `staging` and overridden with the `default_context` field in the configuration file.

  There are extra safety features when deploying to the production context, which defaults to `production` and may be overridden with the `production_context` field in the configuration file.

  Kubernetes configuration is organized by Kubernetes context name, under the `./platform` directory.  For example, the Kubernetes configuration for the default contexts (`staging` and `production`) is stored under `./platform/staging` and `./platform/production` respectively.

### Operations

### Status

Arguments: 
* `context`: Kubernetes context (default `staging`, or the value of `staging_context`)

Displays the statuses of all deployable Kubernetes objects, including image version and number of pods running/desired.  Objects which exist in the Kubernetes configuration directory but don't exist in the cluster are listed as `MISSING`, for example:

```shell
$ rops status
Currently running (staging):
  * MISSING   web-activity-purge (cronjob)
  * gfc50028b web-archive-media-files (cronjob)
  * gfc50028b web-company-report (cronjob)
  * gfc50028b web-subscriptions (cronjob)
  * gfc50028b web-sync-billing (cronjob)
  * gfc50028b jobs [1/1] (deployment)
  * gfc50028b web [1/1] (deployment)
```

### Build

Arguments: 
* `branch`: Git branch/commit (default `master`, or the value of `default_branch`)

Builds the Docker image(s), optionally specifying a Git branch name.

The image will be tagged with the shortened Git commit ID prefixed with a `g` (e.g. `g12345678` ).  If a non-default branch name is specified, it will be appended to the image tag (e.g. `g1234abcd-feature`). The build sets the full Git commit ID in the container image as the `GIT_VERSION` environment variable.

The build sets the number of cores to use for building as the `JOBS` environment variable (usually passed to `bundle` or `make`).  By default, it uses one less than the total number of CPU cores, although you can override this by setting the `R360_BUILD_CORES` environment variable.


```shell
$ rops build feature
Building image web:gfc50028b-feature using 7 cores ...
...
STEP 15/16: ARG GIT_VERSION
--> 69cfcafa4c3
STEP 16/16: ENV GIT_VERSION=$GIT_VERSION
COMMIT web:gfc50028b-feature
--> 8c5ea56990b
Successfully tagged localhost/web:gfc50028b-feature
8c5ea56990bfb1329b8180e4826fca7c5fb08d14d2097e9a05e29296c669cc86
```

### Push

Arguments: 
* `branch`: Git branch/commit (default `master`, or the value of `default_branch`)

Builds the Docker image, if necessary (as in `rops build` above), then pushes the image to the Docker registry.

```shell
$ rops push feature
Local image web:gfc50028b-some-branch already exists
...
Writing manifest to image destination
Storing signatures
```

### Deploy

Arguments: 
* `branch`: Git branch/commit (default `master`, or the value of `default_branch`)
* `context`: Kubernetes context (default `staging`, or the value of `default_context`)

Deploys the Docker image to Kubernetes, building and pushing if necessary (like `rops push`).  Displays the currently running versions (like `rops status`), and any changes to the Kubernetes object configuration, and prompts for confirmation.  `branch` must be specified if deploying to the production context.

The Kubernetes configuration is taken from the Git repository on the same branch/commit as the source code to build.  Only Kubernetes objects that reference one of the built `images` will be deployed to the cluster (e.g. `Pod`, `Deployment`, `CronJob`, `StatefulSet`, etc.).  Other Kubernetes object (e.g. `ConfigMaps`, `Secrets`, `Service`, `Ingress`, etc.) will not be automatically deployed, even if they're in the same YAML file as other objects.  They will need to be applied to the cluster manually.

```shell
$ rops deploy
Currently running (staging):
  * MISSING   web-activity-purge (cronjob)
  * gfc50028b web-archive-media-files (cronjob)
  * gfc50028b web-company-report (cronjob)
  * gfc50028b web-subscriptions (cronjob)
  * gfc50028b web-sync-billing (cronjob)
  * gfc50028b jobs [1/1] (deployment)
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
cronjob.batch/web-activity-purge created
```
