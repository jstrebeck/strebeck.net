---
title: "Homelab Configuration: GitOps on Talos Kubernetes with Argo CD"
date: "2026-01-18T18:28:23-08:00"
author: "Josh Strebeck"
tags: ["homelab", "kubernetes", "talos", "argocd", "gitops", "proxmox", "rook-ceph", "mlops", "kserve", "mlflow"]
summary: "Everything my homelab cluster runs is declared in one repository and delivered by Argo CD. Merging to main is the deployment. This is how the platform is built, how the GitOps workflow is guarded, and what runs on top of it."
draft: false
---

Source code: [jstrebeck/Homelab-Configuration](https://github.com/jstrebeck/Homelab-Configuration)

This repo defines a four-node Kubernetes cluster running on Talos Linux VMs on Proxmox, along with every platform service on it. There is exactly one manifest that ever gets applied by hand. Everything else is an Argo CD `Application`, and a pull request merged to `main` is what deploys it. The lab started in 2022 as Ubuntu VMs built with Terraform and turned into a kubeadm cluster with Ansible. It has since moved to Talos, from Longhorn to Rook-Ceph, and most recently from `kubectl apply` runbooks to GitOps.

![Argo CD applications list showing every platform component synced and healthy](/images/homelab-argocd-apps.jpg)

## The Cluster

The nodes are Proxmox VMs running [Talos Linux](https://www.talos.dev/), one control plane and three workers with 8 vCPU and 32 GiB each. Talos is immutable and API-managed with no SSH and no package manager, so the node OS is not something to administer. Anything that needs host access, like Ceph OSDs or node-exporter, has to be granted explicitly through Pod Security labels. The machine-config patches live in the repo, including the one that makes every node trust the in-cluster container registry.

Networking is Flannel with MetalLB in layer 2 mode handing out LAN addresses to `LoadBalancer` services, so every LAN-facing UI gets its own IP with no ingress controller to run. Internet traffic enters only through a Cloudflare Tunnel whose connectors dial out from inside the cluster, which means no ports are opened on the home router and the home IP is never exposed.

Storage is Rook-Ceph across three 500 GiB OSDs with three-way replication. It exposes block, shared filesystem, and object storage classes from one system that survives the loss of any single worker. Ceph is the most operationally demanding thing in the cluster, and it is the one app Argo CD will never prune.

## GitOps with Argo CD

Argo CD runs the app-of-apps pattern. A single root `Application` points at a directory of files, and each file declares the applications for one component: Helm charts with pinned versions and values kept next to the component, upstream manifests wrapped in kustomize, or filtered directories of plain YAML. Sync waves order a cold start so projects come first, then Argo CD itself, MetalLB, storage, monitoring and cert-manager, KServe, and finally workloads.

The interesting part was adopting a cluster that was already in use. Nothing could be recreated, and some live resources had drifted from the files through hand-applied patches and resized Ceph requests. Argo CD was configured with annotation-based resource tracking so it would not touch the instance labels Helm charts use in selectors, release names matched the original installs, and every app was created without automated sync and diffed first. Live drift was either written back into Git or explicitly ignored before the first sync. The migration restarted exactly one pod and no workloads.

## Guardrails

The default Argo CD sync policy is automated sync with pruning and self-heal. That is the wrong default when the platform apps own CRDs, namespaces, and PVCs, because pruning a CRD deletes every custom resource of that kind in the cluster and pruning a PVC deletes data. So the policy here is deliberately uneven.

- **Every app syncs automatically** on merge to `main`.
- **Pruning is manual** for all platform apps. A removed manifest shows up as requiring pruning and is deleted with an explicit command after review.
- **Self-heal is on** only for components that change through Git alone. It stays off for the ML stack while that is still being built out by hand.
- **No resources finalizer** on any `Application`, so deleting one from Argo CD never cascades into the cluster.
- **Secrets never enter Git.** The repo is public. Manifests reference secrets by name, each component README documents how to create them, and Argo CD never creates, changes, or prunes them.

`AppProject`s split trust the same way. The platform project may manage cluster-scoped resources, while each application project is confined to its own namespace and its own source repository.

## Validation and Upgrades

Every pull request runs a validation workflow. A script renders every `Application` exactly as Argo CD would, using Helm with the pinned chart and values, kustomize, or the filtered directory, and fails if a path or values file is missing. The output is checked with kubeconform against the Kubernetes 1.34 schemas and the CRD schemas for Ceph, Prometheus, cert-manager, and KServe. Terraform formatting is checked and gitleaks scans the full history.

Renovate keeps chart and image versions current with a pull request per update on a weekly schedule. The Rook-Ceph operator and cluster charts are grouped so they move together, the KServe charts are grouped the same way, and major upgrades wait for approval. Merging the PR is the upgrade.

## The ML Platform

The newest layer is an MLOps stack for my ML projects. MLflow 3 runs as the tracking server and model registry with a PostgreSQL backend, and artifacts live in an S3 bucket on SeaweedFS. SeaweedFS was chosen over MinIO, which no longer publishes community images, and over Ceph's own object gateway, whose bucket and user management was heavier than the use case needed. It runs as a single pod on a Ceph-backed volume, with a static identity file giving each consumer keys scoped to only the buckets it needs.

KServe serves the models in Standard mode, where each `InferenceService` becomes a plain Deployment, Service, and HPA. That avoids running Knative and Istio for a few always-on models, at the cost of scale-to-zero and canary splitting. cert-manager is installed only to issue KServe's webhook certificate.

The piece I am most pleased with is a custom storage initializer. KServe's built-in initializer does not understand MLflow registry URIs, so a small `ClusterStorageContainer` claims the `models:/` prefix, resolves an alias like `champion` against MLflow's REST API, and downloads the model files through the artifact proxy with no S3 credentials at all. Promoting or rolling back a model means moving the alias and restarting the predictor pods. Git does not change.

Each application gets its own PostgreSQL StatefulSet in its own namespace with a pinned image, non-root user, and readiness probes. No operator yet. CloudNativePG is the answer if any database ever needs replicas or point-in-time recovery.

## Platform Here, Workloads Elsewhere

Applications running on the cluster keep their manifests in their own repositories. This repo holds only the `AppProject` and `Application` for each one. The application's CI builds an image, pushes it to the in-cluster registry, and bumps the tag in its own homelab overlay, which Argo CD rolls out. The contract between the two repos is just the namespace, the secret names, and the overlay path.

## Decisions on the Record

Every design choice above is written down as an Architecture Decision Record in the repo, with the context, the decision, and the trade-offs accepted. The Terraform, Ansible, and Longhorn code from earlier generations of the lab stays in the repo as a record of how it got here, and the Talos migration itself is covered in [a separate post](/posts/homelab-kubernetes-cluster/).

The whole cluster can be rebuilt from this repo in three steps: patch the Talos nodes to trust the registry, install Argo CD and hand it the root application, then recreate the secrets from each component's README. Argo CD installs everything else in wave order and adopts its own release on the first sync.
