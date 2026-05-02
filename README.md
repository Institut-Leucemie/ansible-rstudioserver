# ansible-rstudioserver

Ansible playbook to deploy [RStudio Server](https://posit.co/products/open-source/rstudio-server/) backed by a [Miniforge](https://github.com/conda-forge/miniforge) conda environment, on Ubuntu 24.04.

Two deployment modes are supported:

- **shared** — multi-user server (PAM auth, behind a reverse proxy)
- **dedicated** — single-user VM with block storage and optional S3 sync (e.g. OVH Public Cloud)

R and all packages are installed inside a conda environment, independently of the system R. This makes the environment fully reproducible and upgradeable without touching the OS.

---

## Requirements

- Ubuntu 24.04 LTS
- Ansible ≥ 2.14
- `community.general` collection (`ansible-galaxy collection install community.general`)
- Python 3 on the target host

---

## Usage

```bash
# Clone the repo
git clone https://github.com/institut-leucemie/ansible-rstudioserver.git
cd ansible-rstudioserver

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Run against your inventory
ansible-playbook playbook.yml -i inventory/<your-inventory>
```

### Dry-run first

```bash
ansible-playbook playbook.yml -i inventory/<your-inventory> --check --diff
```

---

## Role variables

All variables have defaults defined in `roles/rstudio_server/defaults/main.yml`.
Override them in your inventory's `group_vars/`.

### Mode

| Variable | Default | Description |
|---|---|---|
| `rstudio_mode` | `dedicated` | `shared` or `dedicated` |

### Network

| Variable | Default | Description |
|---|---|---|
| `rstudio_port` | `8787` | RStudio Server listening port |
| `rstudio_bind_address` | `0.0.0.0` | Bind address (`127.0.0.1` if behind a reverse proxy) |
| `rstudio_root_path` | *(unset)* | Set to e.g. `/rstudio` if served under a subpath (nginx `location /rstudio/`) |

### Miniforge / Conda

| Variable | Default | Description |
|---|---|---|
| `miniforge_version` | `26.1.1-3` | Miniforge installer version |
| `miniforge_install_dir` | `/opt/miniforge` | Where Miniforge is installed |
| `conda_env_name` | `rstudio-server` | Conda environment name |
| `r_packages` | `[r-base, r-biocmanager]` | Packages to install in the conda env (conda-forge + bioconda) |

### RStudio Server

| Variable | Default | Description |
|---|---|---|
| `rstudio_version` | `2026.01.2-418` | RStudio Server version to install |

### Dedicated mode only

| Variable | Default | Description |
|---|---|---|
| `rstudio_user` | `rstudio` | System user created for RStudio |
| `rstudio_password` | `changeme` | User password (use vault) |
| `block_storage_device` | `/dev/sdb` | Block device to format and mount |
| `block_storage_mount` | `/data` | Mount point for block storage |
| `rstudio_enable_rclone` | `true` | Enable rclone S3 sync on shutdown |
| `rclone_remote_name` | `ovh_s3` | rclone remote name |
| `rclone_bucket` | *(vault)* | S3 bucket name |

---

## Inventory examples

Three example inventories are provided under `inventory/`:

### `artbio` — shared server, local execution

Runs on the RStudio host itself (`ansible_connection: local`).
Reuses an existing conda environment created during a previous deployment.

```yaml
# inventory/artbio/group_vars/all.yml
rstudio_mode: shared
rstudio_bind_address: "127.0.0.1"
rstudio_root_path: /rstudio
rstudio_enable_rclone: false
conda_env_name: rstudio-server_4.3.1
miniforge_install_dir: /opt/rstudio-server_conda/conda
```

### `gce-test` — shared server, minimal config

Minimal shared configuration used for testing on GCE.

```yaml
# inventory/gce-test/group_vars/all.yml
rstudio_mode: shared
rstudio_bind_address: "127.0.0.1"
rstudio_root_path: /rstudio
rstudio_enable_rclone: false
conda_env_name: rstudio-server
r_packages:
  - r-base
  - r-biocmanager
```

### `usegalaxy` — shared server, full bioinformatics stack

Shared server for a research institute. Full single-cell and spatial transcriptomics stack (Seurat, Bioconductor, GDAL, HDF5, etc.) with R 4.5.3.

See `inventory/usegalaxy/README.md` for details.

### `leucemie` — dedicated VM (OVH Public Cloud)

Single-user VM with 1 TB block storage and S3 sync on shutdown.
Credentials are managed with ansible-vault.

---

## Nginx integration (shared mode)

In shared mode, RStudio Server binds to `127.0.0.1:8787` and is served under a subpath by nginx.

Minimal nginx configuration:

```nginx
location /rstudio/ {
    rewrite ^/rstudio/(.*)$ /$1 break;
    proxy_pass http://127.0.0.1:8787;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 20d;
}
```

Set `rstudio_root_path: /rstudio` and `rstudio_bind_address: "127.0.0.1"` in your inventory to match.

---

## Building a custom R environment

The `r_packages` variable accepts any package available on [conda-forge](https://conda-forge.org) or [bioconda](https://bioconda.github.io). Packages are installed via `mamba create` at deploy time.

Example for a single-cell RNA-seq environment:

```yaml
r_packages:
  - r-base=4.5.3
  - r-biocmanager
  - r-seurat
  - r-seuratobject
  - bioconductor-deseq2
  - bioconductor-scater
  - bioconductor-singlecellexperiment
  - r-ggplot2
  - r-dplyr
  - hdf5
  - r-hdf5r
  - python
  - numpy
  - scipy
```

For a reference list covering spatial transcriptomics (Visium, MERFISH), single-cell RNA-seq, and functional analysis, see `inventory/usegalaxy/rstudio-server_r453_environment_loose.yml`.

---

## License

GPL-3.0 — see [LICENSE](LICENSE).
