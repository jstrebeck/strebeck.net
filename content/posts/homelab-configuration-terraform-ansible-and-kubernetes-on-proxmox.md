---
title: "Homelab Configuration: Terraform, Ansible, and Kubernetes on Proxmox"
date: "2026-01-18T18:28:23-08:00"
author: "Josh Strebeck"
tags: ["homelab", "proxmox", "terraform", "ansible", "kubernetes", "talos", "infrastructure-as-code"]
summary: "The infrastructure as code behind my homelab: cloud-init templates and Terraform for Proxmox VMs, Ansible for kubeadm, and the manifests that run on the cluster today."
draft: false
---

Source code: [jstrebeck/Homelab-Configuration](https://github.com/jstrebeck/Homelab-Configuration)

This repo holds everything that defines my homelab, from the VM templates on the Proxmox host up to the workloads running on Kubernetes. It started in 2022 and has changed shape a few times as the cluster moved from kubeadm to Talos, but the principle stayed the same: nothing on the hypervisor should be built by hand.

## Layer 1: Proxmox Templates and Terraform

The base is an Ubuntu 22.04 cloud image turned into a Proxmox template. A short script uses `virt-customize` to bake in the QEMU guest agent, then a series of `qm` commands import the disk, attach a cloud-init drive, enable the serial console, and mark the VM as a template.

Terraform, using the Telmate Proxmox provider, clones that template into real machines. The repo has separate modules for a three node Kubernetes cluster, an OpenVPN gateway, a self hosted GitHub Actions runner used by my [Cloud Resume pipeline](/posts/cloud-resume-project-from-s3-to-ecr-and-kubernetes/), and larger VMs for testing ECS Anywhere and EKS Anywhere. Each resource sets CPU, memory, disk, a static IP through cloud-init, and an SSH key, and uses a `count` so adding a node is a one line change. API credentials live in an untracked `credentials.auto.tfvars` file.

## Layer 2: Ansible and kubeadm

The original cluster was built with kubeadm. A set of Ansible playbooks installs the container runtime and Kubernetes packages on every host, switches Docker to the systemd cgroup driver, runs `kubeadm init` on the control plane, applies Calico for networking and the Kubernetes dashboard, then fetches the join command and joins the workers. An inventory file groups hosts into server, agent, and storage roles.

This worked, but keeping the nodes patched and consistent was manual effort. In 2024 I replaced kubeadm with Talos Linux, which I wrote about in [a separate post](/posts/homelab-kubernetes-cluster/). The Ansible playbooks stay in the repo as a record of the first approach.

## Layer 3: Cluster Services

The `Kubernetes` directory contains the pieces that make a bare cluster useful, each with a short README of the exact commands to apply it.

- **MetalLB** in layer 2 mode with an address pool on the LAN, so `LoadBalancer` services get real IPs
- **Longhorn** and **Rook-Ceph** for persistent storage, including the Talos machine config patches for the extra mounts and kernel modules they need
- **A private container registry**, along with the Talos patch that lets every node pull from it over plain HTTP
- **kube-prometheus-stack** with a values file that exposes Grafana on a LoadBalancer and enables persistence
- **Cloudflare Tunnel** for exposing selected services without opening inbound ports

## What This Gives Me

The whole lab can be rebuilt from this repo. Terraform stamps out the VMs, the Talos configs turn them into nodes, and the manifests bring back storage, networking, monitoring, and ingress. When I want to try something new, I add a module and apply it, and when it does not work out, I destroy it and nothing else is affected.
