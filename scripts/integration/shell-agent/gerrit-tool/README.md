# Gerrit configuration and review preparation

This guide has two separate workflows:

1. configure and operate the Linux machine that hosts Gerrit and its CI backend;
2. configure a developer's local Linux checkout before uploading a review.

Run repository commands from the `MyPiCarX` root. Never store a password, HTTP
password, access token, cookie, private SSH key, or authenticated URL in this
repository. Register only public SSH keys in the Gerrit web UI.

## 1. Gerrit server configuration

This section is for the administrator of the Linux machine that runs Gerrit.
Developer workstations that only upload reviews should skip to section 2.

### Assess the server host

Run the read-only local Linux assessment:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh assess
```

Select an assessed IPv4 address belonging to the intended Ethernet or Wi-Fi
interface. Do not use a loopback, container bridge, virtual-machine-only, or
guessed address. Reassess the host when DHCP changes its address.

### Configure the server profile

Review
`scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.conf` before the first
installation. At minimum, confirm:

- `GERRIT_SERVER_IP` and `GERRIT_SERVER_HOST` use the assessed address;
- `GERRIT_STORAGE_PATH` is empty for `$HOME/gerrit-site` or is an approved,
  validated persistent path;
- `GERRIT_PROJECT` and `GERRIT_BRANCH` match the repository being hosted;
- `GERRIT_HTTPS_PORT`, `GERRIT_SSH_PORT`, and `GERRIT_HTTP_PORT` do not
  conflict with another service;
- administrator name, username, and email identify the intended owner;
- the Gerrit download URL and SHA-256 identify the reviewed Gerrit release.

The integrated multi-repository architecture uses `xWalk-rpi5-hw` with `master`.
The current monorepo deployment uses `xWalkPiCarAI` with `master`. Do not mix a
project name with the other project's review branch.

The configuration file may contain non-secret deployment values:

```bash
export GERRIT_SERVER_IP="192.168.1.158"
export GERRIT_SERVER_HOST="$GERRIT_SERVER_IP"
export GERRIT_PROJECT="xWalkPiCarAI"
export GERRIT_BRANCH="master"
export GERRIT_HTTPS_PORT="18443"
export GERRIT_SSH_PORT="29419"
export GERRIT_HTTP_PORT="18080"
```

Do not add the administrator password or a private certificate key. The
installer prompts for the initial password without echoing it.

Validate a non-default storage path before installation:

```bash
scripts/integration/py-agent/gerrit-tool/shell-script/gerrit-storage-check.sh
```

Never run two Gerrit processes against one site directory.

### Install or start Gerrit

Install the local non-root server once:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh install
```

Start an existing installation after a reboot:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh start
```

When the protected `$HOME/.xwalk-ci.env` file exists, this command starts the
CI worker after Gerrit and the HTTPS proxy. The matching status, stop, and
restart controls include the configured worker.

The installer keeps applications, the Gerrit site, generated controls, and
certificates under the administrator's home directory. It does not require an
interactive `sudo` command or install a system-wide Gerrit service.

### Verify Gerrit and HTTPS

Check the Gerrit process, installation, HTTPS proxy, and configured browser
address:

```bash
"$HOME/bin/gerrit-status"
"$HOME/bin/gerrit-check"
"$HOME/bin/gerrit-caddy-control" status
git config --file "$HOME/gerrit-site/etc/gerrit.config" --get gerrit.canonicalWebUrl
```

Trust only the generated public certificate after checking its fingerprint.
Never distribute `$HOME/gerrit-site/etc/gerrit-self-signed.key`.

Verify the Gerrit SSH command endpoint with an administrator account:

```bash
ssh -p 29419 joxy@192.168.1.158 gerrit version
```

### Configure the CI backend

Select exactly one verification backend for a Gerrit project.

For the current repository-owned worker, prepare the protected CI environment
and least-privilege service identity as described by the administrator guide.
The normal Gerrit start command then includes the worker. Use its direct
control for recovery when required:

```bash
"$HOME/bin/gerrit-ci-control" start
```

Check its process and read-only dashboard health:

```bash
"$HOME/bin/gerrit-ci-control" status
curl --fail --show-error --silent --cacert "$HOME/gerrit-site/etc/gerrit-self-signed.crt" "https://192.168.1.158:18443/ci/health"
```

If the project later selects Zuul, an administrator must install and operate the Zuul scheduler,
executor, web service, Nodepool launcher, Gerrit connection, and the
`ubuntu-24.04-xwalk-ci` node image. Repository `.zuul.yaml` and playbooks do not
install those services. Grant the Zuul account read access to patch-set refs and
permission to vote `Verified +1` or `Verified -1`.

Do not run Zuul and the legacy worker against the same project because both
services could test and vote on one patch set.

### Verify the server before developer uploads

Confirm all of the following:

- the Gerrit web URL opens through HTTPS;
- Gerrit SSH accepts the intended account and port;
- the target project and review branch exist;
- the developer has project visibility and review-push permission;
- the selected CI backend is connected to Gerrit's event stream;
- active patch-set uploads trigger CI while WIP uploads defer CI;
- the CI dashboard or Zuul result page is reachable;
- no private key, password, token, or authenticated URL is stored in Git.

Complete server installation and permission details are in the
[Gerrit installer guide](../../py-agent/gerrit-tool/README.md) and the
[local Linux server guide](../../py-agent/gerrit-tool/local-linux/README.md).

## 2. Local Linux development machine configuration

This section is for each developer machine that creates commits and uploads
reviews. It does not install or modify the Gerrit server.

### Define the review endpoint

Set values matching the server's project and branch. These examples target the
current `xWalkPiCarAI/master` deployment:

```bash
export GERRIT_HOST="192.168.1.158"
export GERRIT_SSH_PORT="29419"
export GERRIT_USER="joxy"
export GERRIT_PROJECT="xWalkPiCarAI"
export GERRIT_REVIEW_BRANCH="master"
```

For an independent component or the integrated `xWalk-rpi5-hw` repository, use its
exact Gerrit project name and normally set `GERRIT_REVIEW_BRANCH=master`.

Confirm the expected local checkout before changing Git configuration:

```bash
test "$(git rev-parse --show-toplevel)" = "$PWD"
```

### Configure the Git identity

Use the name and email registered with the Gerrit account. Keep the identity
local to this checkout when it should not affect other repositories:

```bash
git config --local user.name "Joxy John"
git config --local user.email "joxjoh24@student.hh.se"
git config --local --get user.name
git config --local --get user.email
```

### Configure SSH access

Each developer is responsible for securely creating, selecting, protecting,
and rotating their own SSH key outside this repository workflow. Never share a
private key or copy it into the repository.

Create a dedicated Gerrit key when needed. Choose a different path if this one
already exists; do not overwrite an existing private key:

```bash
ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_xwalk_gerrit" -C "joxjoh24@student.hh.se"
```

Open Gerrit and select **Settings → SSH Keys**. Add only the public key:

```bash
cat "$HOME/.ssh/id_ed25519_xwalk_gerrit.pub"
```

Load the private key into the current SSH agent when required:

```bash
ssh-add "$HOME/.ssh/id_ed25519_xwalk_gerrit"
```

Verify the account and server before configuring the remote:

```bash
ssh -p "$GERRIT_SSH_PORT" "$GERRIT_USER@$GERRIT_HOST" gerrit version
```

Gerrit supports commands rather than a normal interactive shell, so an SSH
shell warning after successful authentication is expected.

### Configure the Gerrit remote

Inspect existing remotes first:

```bash
git remote -v
```

Add the Gerrit review remote once:

```bash
git remote add gerrit "ssh://$GERRIT_USER@$GERRIT_HOST:$GERRIT_SSH_PORT/$GERRIT_PROJECT"
```

If `gerrit` already exists, inspect it instead of adding a duplicate:

```bash
git remote get-url gerrit
```

Correct it only after confirming the intended Gerrit project:

```bash
git remote set-url gerrit "ssh://$GERRIT_USER@$GERRIT_HOST:$GERRIT_SSH_PORT/$GERRIT_PROJECT"
```

Confirm that the account can see the intended project:

```bash
ssh -p "$GERRIT_SSH_PORT" "$GERRIT_USER@$GERRIT_HOST" gerrit ls-projects --project "$GERRIT_PROJECT"
```

Do not configure or push a GitHub remote from an independent component
repository. Gerrit is the review entry point.

### Install the Change-Id hook

Download Gerrit's `commit-msg` hook and make it executable before creating a
commit:

```bash
scp -P "$GERRIT_SSH_PORT" "$GERRIT_USER@${GERRIT_HOST}:hooks/commit-msg" .git/hooks/commit-msg
chmod 0755 .git/hooks/commit-msg
```

If a new commit was made without a `Change-Id`, amend it once after installing
the hook:

```bash
git commit --amend --no-edit
```

Never replace the existing `Change-Id` when updating a Gerrit review.

### Check the commit before upload

Review the branch, worktree, remote, whitespace, commit sign-off, and
`Change-Id`:

```bash
git branch --show-current
git status --short
git remote -v
git diff --check HEAD^
git log -1 --format=full
```

Create a signed-off commit when one does not exist:

```bash
git add path/to/changed-file
git commit -s
```

Run relevant host-safe checks before upload:

```bash
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh build-and-test gcc Debug
```

Do not run physical hardware tests as part of review preparation.

### Upload the review

Upload an active patch set after the administrator confirms Gerrit and CI are
ready:

```bash
git push gerrit "HEAD:refs/for/$GERRIT_REVIEW_BRANCH"
```

Upload as work in progress when CI must be deferred:

```bash
git push gerrit "HEAD:refs/for/$GERRIT_REVIEW_BRANCH%wip"
```

For later revisions, amend the existing commit without changing its
`Change-Id`, then repeat the same push command. Gerrit creates a new patch set
in the existing review.

### Troubleshoot the local machine

- `Permission denied (publickey)`: load the intended private key and confirm
  its public key is registered under the correct Gerrit account.
- `remote gerrit already exists`: inspect it with `git remote get-url gerrit`;
  do not add a duplicate.
- `missing Change-Id in message footer`: install the `commit-msg` hook and
  amend the commit once.
- `no new changes`: the tree matches the current patch set; make the intended
  change before uploading another revision.
- no CI run: confirm the change is active rather than WIP and ask the
  administrator to verify the selected CI backend and event stream.
- `502 Bad Gateway` below `/ci`: Gerrit may be healthy while the CI log server
  is stopped; ask the administrator to check the CI service and `/ci/health`.
