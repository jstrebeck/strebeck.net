---
title: "Fastest way to create a homelab Kubernetes cluster"
date: "2024-10-12T12:30:57-08:00"
tags: ["kubernetes", "homelab"]
---

Talos is preconfigured operating system that makes it easy to setup your control plane and get nodes added. 

You can read more about them here.
[Talos](https://www.talos.dev)


I recommend creating a Proxmox cluster and utilizing this doc [Talos Proxmox guide](https://www.talos.dev/v1.8/talos-guides/install/virtualized-platforms/proxmox/)

Once you have a VM created you can follow my [Homelab-Configuration](https://github.com/jstrebeck/Homelab-Configuration) to create templates that can be used to deploy as many nodes as you would like.

In the end you should have a working cluster
![k9s_image](https://k9scli.io/assets/screens/pods.png)
