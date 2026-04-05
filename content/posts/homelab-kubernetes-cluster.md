---
title: "Fastest way to create a homelab Kubernetes cluster"
date: "2024-10-12T12:30:57-08:00"
tags: ["kubernetes", "homelab"]
---

If you've been wanting to run Kubernetes at home but dread the idea of manually bootstrapping kubeadm on a handful of VMs, [Talos Linux](https://www.talos.dev) is worth a look. It's a purpose-built OS for Kubernetes — no SSH, no package manager, no shell. You manage the entire thing through an API and config files, which sounds limiting until you realize it means every node is identical and reproducible from day one.

I've been running a Talos cluster on Proxmox for a while now, and it's become the backbone of pretty much everything I tinker with at home. Here's how I set it up and what I'm running on it.

## Getting Started with Proxmox and Talos

The foundation is a Proxmox hypervisor. I run Talos nodes as VMs, which makes it trivial to add or rebuild nodes without touching physical hardware. Talos has a solid guide for this: [Talos Proxmox guide](https://www.talos.dev/v1.8/talos-guides/install/virtualized-platforms/proxmox/).

Once you have a base VM created, you can follow my [Homelab-Configuration](https://github.com/jstrebeck/Homelab-Configuration) repo to create templates that let you stamp out as many nodes as you want. The whole idea is that nodes are cattle, not pets — if one acts up, you just replace it from the template.

The cluster itself is managed entirely through `talosctl`. Need to patch a machine config? `talosctl patch mc -p @patch.yaml --mode=auto`. Need to upgrade a node? `talosctl upgrade --preserve`. No SSHing into boxes and hoping you remember what you changed last time.

## Storage: Rook-Ceph

This was the most involved piece of the setup. I'm running [Rook-Ceph](https://rook.io/) for distributed storage across the cluster. Each Proxmox VM has a secondary disk attached that Ceph uses as an OSD — so the storage is replicated across nodes and survives individual VM failures.

Getting Ceph working on Talos has a few gotchas. The kernel modules Ceph needs (`rbd`, `ceph`, `iscsi_tcp`) aren't included in the default Talos image. You have to install system extensions like `ghcr.io/siderolabs/iscsi-tools` and then do a node upgrade with the `--preserve` flag to make the modules available. Just adding them to `machine.kernel.modules` in the config isn't enough if the modules aren't actually in the kernel image — I spent some time debugging that one. You can verify everything loaded correctly by checking `/proc/modules` on each node.

You also need to configure `kubelet.extraMounts` for `/var/lib/rook` so Ceph has somewhere to store its data. For homelabs without spare disks, you can even create loop devices with `truncate -s 50G /var/lib/rook/loop0.img` — not ideal for performance, but it works for learning.

I'll be honest though — Ceph is resource hungry. Each OSD eats about 4GB of memory, and I've seen CPU requests hit 86% on two of my four nodes just from the storage layer. I'm currently evaluating lighter alternatives like Longhorn (which also needs the `iscsi-tools` extension on Talos) and local-path-provisioner for workloads that don't need replication.

## Private Container Registry

I run a private Docker registry on the cluster at `192.168.2.203:5000` for pushing custom images. It runs over plain HTTP, which means every Talos node needs the registry added to `machine.registries.insecure` in the machine config. The `insecureSkipVerify` option alone won't cut it — that still tries HTTPS first. You need the `insecure` list for actual HTTP pulls.

This has been great for my [ML project](/posts/training-and-monitoring-ml-models-with-pytorch-mlflow-and-kubeflow/) where I'm building custom Docker images for MLflow and model serving. Push to the local registry, deploy to the cluster, iterate fast.

## Monitoring with Prometheus and Grafana

For observability I'm running the `kube-prometheus-stack` Helm chart from the prometheus-community repo. The main things I changed from defaults:

- Set `grafana.service.type: LoadBalancer` so I can hit Grafana directly from my network instead of port-forwarding every time
- Enabled `grafana.persistence.enabled: true` so dashboards survive pod restarts

Having Prometheus scraping the cluster has been really useful for spotting the Ceph resource problems I mentioned. It's one thing to suspect your storage layer is heavy — it's another to see the actual memory and CPU graphs.

## What I'm Running on It

The cluster started as a Kubernetes playground, but it's grown into something I actually rely on:

- **MLflow tracking server** with PostgreSQL backend and Ceph-backed artifact storage for my ML experiments
- **Private container registry** for custom images
- **Prometheus + Grafana** for cluster monitoring
- Various workloads I'm experimenting with as I build out my MLOps skills

## Was It Worth It?

Absolutely. If you already have a Proxmox server (or any hypervisor, really), standing up a Talos cluster is genuinely fast. The initial cluster takes maybe an hour if you follow the docs. The storage and networking layers are where the real time goes, but that's also where you learn the most.

The biggest selling point of Talos for me is reproducibility. Every node is defined by a config file. If something goes sideways, I regenerate the node from the template and apply the config. No snowflakes, no drift, no mystery.

![k9s_image](https://k9scli.io/assets/screens/pods.png)
