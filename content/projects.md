---
title: "Projects"
ShowToc: false
ShowReadingTime: false
ShowBreadCrumbs: false
---

Most of what I build runs on my homelab, where everything is declared in Git and delivered by Argo CD. So here are the projects the way Argo CD would list them: the project they belong to, where their manifests come from, where they run, and a link to the write-up where there is one. The one Degraded row is intentional.

{{< argo-apps >}}

The homelab itself is the first row. The cluster and every platform service on it are described in [Homelab Configuration](/posts/homelab-configuration-terraform-ansible-and-kubernetes-on-proxmox/), and the rest deploy onto it from their own repositories.
