---
title: "Game Server Platform: Multi-Tenant Minecraft Hosting on Kubernetes"
date: "2026-01-25T16:42:11-08:00"
author: "Josh Strebeck"
tags: ["kubernetes", "python", "fastapi", "nextjs", "homelab", "saas", "stripe", "auth0", "minecraft"]
summary: "A Kubernetes-native hosting platform that provisions isolated game servers through the API, routes players through a single Velocity proxy, and ships with auth, billing, support, and admin tooling."
draft: false
---

Source code: [jstrebeck/game-server-platform](https://github.com/jstrebeck/game-server-platform)

I wanted a project that pushed platform engineering past a toy cluster demo, so I built something shaped like a real SaaS: a multi-tenant game server host. A customer signs up, picks a RAM tier, and gets a Minecraft server with its own hostname in about a minute. Behind that is a FastAPI control plane that talks directly to the Kubernetes API, a shared proxy that routes players by hostname, and all the product plumbing a hosting business needs. It is branded MinecraftHosting.gg and runs on the bare-metal cluster from my [homelab](/posts/homelab-configuration-terraform-ansible-and-kubernetes-on-proxmox/).

![Customer dashboard showing a running server and its connection hostname](/images/game-server-platform-dashboard.png)

## A Server Is Just a Workload

Every hosted server is the same four Kubernetes objects inside a tenant namespace: a `Namespace` named after the user, a `PersistentVolumeClaim` for world data, a single-replica `Deployment` running the game, and a `ClusterIP` `Service`. The Auth0 subject is sanitized into a DNS-safe label that becomes the namespace name, the proxy route name, and the player-facing subdomain, so there is no lookup table to keep in sync.

Kubernetes is also the database. There is no separate store for server state. Whether a server is running comes from the Deployment's replica counts, the installed plugins come from an environment variable on the pod spec, and the RAM allocation comes from the resource limits. Stopping a server scales the Deployment to zero, which frees the compute while the world stays on the PVC. Deleting a server deletes the namespace and lets garbage collection handle the rest.

The provisioning code takes the game as a parameter, and only the image, ports, and init config are Minecraft-specific. The README sketches a template registry for adding other games, and explains why routing, not orchestration, is the hard part for UDP titles that carry no hostname in their handshake.

## One IP, Many Servers

An early version gave every server its own `LoadBalancer`, which burned a public IP per customer and spread the attack surface across dozens of endpoints. The current design puts every tenant behind a single [Velocity](https://papermc.io/software/velocity) proxy on port 25565. Wildcard DNS points at TCPShield for DDoS protection, which forwards to Velocity. The Minecraft handshake includes the hostname the player typed, and Velocity's forced-hosts table maps that to the tenant's `ClusterIP` service using plain cluster DNS across namespaces.

Registering a route at runtime is where it got interesting. The backend writes the new entry to a ConfigMap so it survives proxy restarts, but ConfigMap volume updates propagate slowly and a rollout would disconnect every player on the platform. So the backend also execs into the Velocity pod, writes the updated config, and triggers a reload over RCON. New routes go live in seconds without dropping anyone. The fallback route list is intentionally empty, so a mistyped hostname is rejected rather than falling through to another customer's server.

Backend servers run in offline mode and only trust connections from the proxy. Velocity authenticates players against Mojang and forwards identity with an HMAC-signed payload. The shared secret lives in a Kubernetes `Secret` that the backend copies into each tenant namespace at provision time.

## Guardrails on Day-2 Operations

Customers get a real control panel, and every feature goes through the Kubernetes API with limits. Live logs stream over a WebSocket from a pod log watch, with the namespace derived from the JWT and never from user input. The console runs commands through `pods/exec` and `rcon-cli`, blocks lifecycle commands in favor of the UI, and audit-logs everything. The config editor works from an allow-list of files with a size cap. World uploads spin up a short-lived busybox pod that mounts the tenant's PVC, stream a tar archive over exec stdin, and check for zip-slip paths and a valid `level.dat` before the server can start.

Memory requests equal limits, so the scheduler reserves exactly what the customer pays for. The JVM heap is set to the limit minus headroom for metaspace and native buffers so the OOM killer does not take the server down under load. The backend sums memory limits across every running tenant and refuses checkout or upgrades when the cluster cannot schedule more, which is what makes the pricing model honest.

## The Rest of the Product

Infrastructure alone does not make a platform, so the customer lifecycle is built out end to end. Auth0 handles OIDC login, and the backend validates RS256 JWTs against a cached JWKS with role-based claims gating the admin API. Email verification is required before provisioning, with a fallback to the Management API because claims can be stale right after a user clicks the link.

Stripe handles four RAM tiers with a 48-hour no-card trial, Checkout for subscriptions, the Customer Portal for card management, and prorated in-app upgrades gated by the capacity check. Signature-verified webhooks sync state into Auth0 metadata. A cancellation scales the server to zero automatically, and a failed payment moves the account to past due, where start requests return a 402.

There is also a referral program with Stripe customer-balance credits, a support form through Mailgun with reply-to set to the customer, versioned Terms of Service acceptance, and an admin dashboard with user search, impersonation for debugging, a maintenance banner, and an allocated-versus-used RAM view backed by Prometheus.

## What I Would Do Next

The platform worked end to end, but I would change a few things before running it at scale. The imperative create calls should become a `GameServer` CRD with a reconciling controller so drift self-heals. The backend's cluster-wide `pods/exec` permission should be replaced with per-tenant role bindings and a Velocity plugin that watches the API. Each namespace needs a default-deny `NetworkPolicy`, resource quotas, and Pod Security Admission. Backups with k8up were in progress, and the manifests should move to Argo CD with images tagged by commit SHA instead of `latest`.

The whole thing, from control plane to every customer's game server, ran on hardware I own. That meant owning the load balancer IPs, the storage behind the PVCs, the container registry, and the monitoring stack too, which is a big part of why the project was worth doing.
