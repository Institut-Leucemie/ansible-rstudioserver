# Inventory: usegalaxy

## Description

Configuration RStudio Server pour **usegalaxy.sorbonne-universite.fr** — mode **shared** (multi-utilisateur).

### Stack

- **OS**: Ubuntu 24.04 LTS
- **R**: 4.5.3 (latest stable, mai 2026)
- **Miniforge**: 26.1.1-3
- **RStudio Server**: 2026.04.0-526 "Globemaster Allium"
- **Conda env**: `/opt/rstudio-server_miniforge/envs/rstudio-server_4.5.3`

### Packages R inclus

**Stratégie de versioning**: Versions **LOOSE** (pas de pinning sauf R lui-même).
Conda négocie les dépendances compatibles à la création de l'environnement.

**Couches principales**:

1. **Spatial Transcriptomics** (Visium + MERFISH)
   - GDAL, Proj, Geos, libspatialite
   - r-terra, r-sf, r-sp, r-raster

2. **Single-Cell RNA-seq**
   - Seurat 5.x, BioconductorPackages core (scater, scuttle, batchelor)
   - Leiden, UMAP, nearest-neighbor tools

3. **RNA-seq & Functional Analysis**
   - DESeq2, EdgeR, Limma
   - clusterProfiler, enrichplot, FGSEA

4. **Visualization**
   - ggplot2, ggtree, plotly, patchwork, pheatmap, etc.

5. **Data Wrangling**
   - tidyverse stack (dplyr, tidyr, stringr)
   - data.table, readr, readxl

6. **System Libraries**
   - HDF5, NetCDF (pour imports de données géospatiales)
   - PostgreSQL (libpq)

7. **Python** (pour reticulate integration)
   - numpy, scipy, pandas, scikit-learn, scikit-image, matplotlib

---

## Utilisation

### Déployer

```bash
cd /path/to/ansible-rstudioserver
ansible-playbook playbook.yml -i inventory/usegalaxy
```

### Options supplémentaires

Pour passer des variables de ligne de commande (override `group_vars/all.yml`):

```bash
ansible-playbook playbook.yml -i inventory/usegalaxy \
  -e "rstudio_version=2026.05.0-daily+128"
```

---

## POST-INSTALL : Packages supplémentaires pour les users

### InferCNV (single-cell analysis)

Depuis RStudio ou terminal:

```r
# Via GitHub (méthode recommandée)
remotes::install_github("broadinstitute/infercnv")

# Ou conda
conda install -n rstudio-server_4.5.3 -c bioconda r-infercnv
```

### Packages R custom

Users peuvent installer via RStudio:

```r
install.packages("package_name")
```

Ou via conda (si le package est dans bioconda/conda-forge):

```bash
conda install -n rstudio-server_4.5.3 -c bioconda r-<package_name>
```

### Packages Python (via reticulate)

Users ouvrent un terminal RStudio et font:

```bash
pip install --user scanpy anndata bbknn
```

Puis dans R:

```r
library(reticulate)
scanpy <- import("scanpy")
```

---

## Notes d'architecture

- **Mode shared**: PAM authentication (users du système)
- **Bind address**: `127.0.0.1:8787` (derrière nginx proxy sur `/rstudio/`)
- **Miniforge**: Installation centralisée; un seul env conda
- **Data access**: Users accèdent à `/mnt/data` (XFS, 277 To)

---

## Troubleshooting

### RStudio refuse de démarrer

```bash
sudo systemctl status rstudio-server
sudo /usr/lib/rstudio-server/bin/rstudio-server verify-installation
```

### Conda env not found

```bash
# Vérifier que l'env existe
/opt/rstudio-server_miniforge/bin/conda info --envs

# Recréer si nécessaire
/opt/rstudio-server_miniforge/bin/mamba create -y \
  -n rstudio-server_4.5.3 \
  -c conda-forge -c bioconda \
  r-base r-seurat bioconductor-deseq2 ...
```

### Package R manquant après install

Vérifier le `rserver.conf`:

```bash
cat /etc/rstudio/rserver.conf | grep "r-libs"
```

Si nécessaire, ajouter le chemin manuellement et restart RStudio:

```bash
sudo systemctl restart rstudio-server
```

---

## Références

- [RStudio Server Docs](https://docs.posit.co/ide/server-pro/)
- [Conda-forge R packages](https://conda-forge.org/docs/maintainer/adding_pkgs.html)
- [Bioconda](https://bioconda.github.io/)
- [Spatial transcriptomics tools](https://www.10xgenomics.com/products/visium-gene-expression)
