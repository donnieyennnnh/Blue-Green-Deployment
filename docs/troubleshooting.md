# Troubleshooting

Real problems I hit building this project, in roughly the order they appeared.

---

## Phase 0 — Setup

### winget says "Found an existing package already installed" but `terraform` isn't on PATH

winget installs HashiCorp Terraform to `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Hashicorp.Terraform_*\` but doesn't always add that directory to PATH. VS Code's integrated terminal also caches the PATH from when VS Code started, so even if PATH is fixed system-wide, VS Code needs a full restart.

**Fix:**
```powershell
# Rebuild the current shell's PATH from both machine and user scopes
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

# Or permanently add Terraform's folder
$terraformDir = "C:\Users\russe\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe"
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$terraformDir", "User")
```

Then **fully close and reopen VS Code** (not just the terminal).

### PowerShell `curl ifconfig.me` triggers a scary "Security Warning"

`curl` in PowerShell is an alias for `Invoke-WebRequest`, which parses HTML by default. Pre-7.0 PowerShell throws a confirmation prompt.

**Fix:** use the real curl.exe:
```powershell
curl.exe ifconfig.me
```

---

## Phase 2 — Terraform

### `data.aws_ami.ubuntu` returned zero results in Singapore

Original filter was `ubuntu/images/hvm-ssd-gp3/ubuntu-jammy-22.04-amd64-server-*`. Canonical publishes Ubuntu AMIs in `hvm-ssd/` in some regions and `hvm-ssd-gp3/` in others. Singapore only had the former.

**Fix:** widen the filter in `terraform/main.tf`:
```hcl
values = ["ubuntu/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-server-*"]
```

Wildcard matches both folder names; `most_recent = true` still picks the latest build.

---

## Phase 3 — Ansible

### "Ansible is being run in a world writable directory, ignoring it as an ansible.cfg source"

WSL mounts `/mnt/c/` with permissions that look "world-writable" to Linux because NTFS can't fully express Unix permissions. Ansible refuses to load `ansible.cfg` from such directories as a safety measure, which causes it to silently ignore both the config AND the inventory it references.

**Fix:** force Ansible to use the config via env var:
```bash
export ANSIBLE_CONFIG="./ansible.cfg"
# Make it permanent:
echo 'export ANSIBLE_CONFIG="./ansible.cfg"' >> ~/.bashrc
```

### "The 'community.general.yaml' callback plugin has been removed"

Ansible 2.13+ removed the standalone yaml callback. The replacement is a built-in option on the default callback.

**Fix in `ansible.cfg`:**
```ini
# Before:
stdout_callback = yaml

# After:
stdout_callback = default
result_format = yaml
```

### `apt update` fails with "File has unexpected size" during UFW install

The default Ubuntu AMI uses the regional mirror (`ap-southeast-1.ec2.archive.ubuntu.com`), which is frequently mid-sync and serves inconsistent Packages.xz vs Release hashes.

**Fix:** add an idempotent task to the playbook to rewrite sources.list to the main Canonical mirror:
```yaml
- name: Use main Canonical apt mirror (regional one lags)
  ansible.builtin.replace:
    path: /etc/apt/sources.list
    regexp: 'http://(?:[a-z0-9-]+\.ec2\.)?archive\.ubuntu\.com'
    replace: 'http://archive.ubuntu.com'
```

### "No package matching 'fail2ban' is available"

`fail2ban` is in the `universe` component. Some Ubuntu AMIs ship with it disabled.

**Fix:** add an idempotent task before fail2ban install:
```yaml
- name: Ensure universe repository is enabled
  ansible.builtin.apt_repository:
    repo: "deb http://archive.ubuntu.com/ubuntu {{ ansible_distribution_release }} universe"
    state: present
    update_cache: true
```

---

## Phase 5 — GitHub Actions CD

### `Not authorized to perform sts:AssumeRoleWithWebIdentity` even with correct trust policy

GitHub recently rolled out **immutable OIDC subjects** at the org/account level. Instead of the classic `repo:owner/repo:ref:refs/heads/main` format, the `sub` claim now includes numeric owner/repo IDs: `repo:owner@12345/repo@67890:ref:refs/heads/main`.

**How to find out:** CloudTrail → Event history → filter by `AssumeRoleWithWebIdentity` → open the event → `userIdentity.userName` shows the actual sub GitHub is sending.

**Fix:** update the role trust policy to match the new format:
```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
  "token.actions.githubusercontent.com:sub": "repo:owner@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main"
}
```

This is actually more secure — if the repo is renamed or transferred, OIDC trust breaks (preventing repo-jacking attacks).

### `Load key "deploy_key": error in libcrypto` → `Permission denied (publickey)`

The private key secret in GitHub got mangled during paste. PowerShell → clipboard → browser conversion can mess with line endings.

**Fix:** pipe the key file directly into the secret via the GitHub CLI (preserves exact bytes):
```powershell
Get-Content $HOME\.ssh\bobross-gallery -Raw | gh secret set EC2_SSH_PRIVATE_KEY --repo OWNER/REPO
```

---

## Phase 7 — Monitoring

### Grafana shows "No data" and Prometheus targets show `context deadline exceeded` on app endpoints

Deploy.sh binds containers to `127.0.0.1:3001` (the EC2 host's loopback). Prometheus is in its own container with its own private network — its "127.0.0.1" is itself, not the EC2 host. So the `host.docker.internal:3001` config resolves to the Docker bridge gateway, which has no process listening on 3001.

**Fix:** put all three monitoring containers on the host network:
```yaml
services:
  prometheus:
    network_mode: host
    command:
      - '--web.listen-address=127.0.0.1:9090'
  grafana:
    network_mode: host
    environment:
      - GF_SERVER_HTTP_ADDR=127.0.0.1
      - GF_SERVER_HTTP_PORT=3000
  node-exporter:
    network_mode: host
```

Then in `prometheus.yml`, change targets to `localhost:3001` and `localhost:3002`.

### Grafana "failed to fetch" after switching to host network

The provisioned datasource was `url: http://prometheus:9090` (container-name resolution via Docker's internal DNS). Host network containers don't get those DNS entries.

**Fix:** update the datasource to use localhost since Grafana is also on host network now:
```yaml
url: http://localhost:9090
```

Restart Grafana to pick up the new config:
```bash
docker compose up -d --force-recreate grafana
```

---

## Docker Desktop on Windows quirks

### `Ctrl+C` doesn't actually stop a `docker run` container

On Windows Docker Desktop, pressing `Ctrl+C` on a `docker run` in the foreground kills the local docker CLI but the container keeps running on the daemon.

**Workaround:** in a second PowerShell window:
```powershell
docker stop <container-name>
```

Or use `docker run -d` from the start to run detached, then `docker stop` when done.

### Daemon not running (`open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified`)

Docker Desktop isn't running.

**Fix:** open Docker Desktop from Start Menu, wait for the whale icon in the system tray to stop animating, then retry.
