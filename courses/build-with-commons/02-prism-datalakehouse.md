---
title: Build a datalakehouse with Prism
image: assets/prism-datalakehouse.png
image_alt: A source flows through a dataset and Prism bronze and silver stages into a governed gold Facet and DS-Fetch.
---
# Dataset → Prism → Facet

A **Prism** is a pipeline. It reads a regular source dataset, transforms each
row with Silver SQL, and publishes a governed **Facet** in Gold.

1. Connect the source with credentials stored in Vault.
2. Define the source dataset.
3. Define the Facet's key, ordering field, history and schema.
4. Select runtime profiles and create the Prism.
5. Run once in dev and follow its job stages.
6. Reconcile counts and keys through DS-Fetch.
7. Add a schedule or webhook only after verification.

Choose the primary key and history mode before the first Gold publish; they
cannot safely change after data exists.
