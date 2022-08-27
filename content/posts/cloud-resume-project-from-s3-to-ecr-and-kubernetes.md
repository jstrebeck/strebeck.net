---
title: "Cloud Resume Project: From S3 to ECR and Kubernetes"
date: "2022-08-27T14:37:25-07:00"
author: "Josh Strebeck"
tags: ["aws", "s3", "cloudfront", "github-actions", "docker", "ecr", "kubernetes", "ci-cd"]
summary: "The original strebeck.net: a static resume site deployed to S3 and CloudFront with GitHub Actions, later containerized and shipped to a homelab Kubernetes cluster through ECR."
draft: false
---

Source code: [jstrebeck/Cloud-Resume-Project](https://github.com/jstrebeck/Cloud-Resume-Project)

This repo was the first version of strebeck.net, built in the spirit of the Cloud Resume Challenge. The idea is simple: put your resume on the web, but use real cloud infrastructure and a real deployment pipeline to get it there. The site itself is a single page of HTML, Bootstrap, and a little JavaScript with sections for experience, education, certifications, and an RSS feed of my Medium posts.

The project went through two distinct phases.

## Phase 1: S3, CloudFront, and GitHub Actions

The first deployment was a static site in an S3 bucket with CloudFront in front of it for HTTPS and caching. A GitHub Actions workflow triggered on every push to `main`, synced the repo contents to the bucket, and then ran a CloudFront invalidation so changes showed up right away. I also experimented with a JavaScript visitor counter, which is a standard piece of the challenge, before removing it to keep the page simple.

For a static resume this was already more infrastructure than the page needed, which was the point. It was a safe place to learn how the pieces fit together.

## Phase 2: Containers, ECR, and a Homelab Cluster

About a year later I rebuilt the pipeline around containers. A `Dockerfile` copies the site into the official Nginx image. The GitHub Actions workflow became two jobs.

1. **Build** runs on a GitHub hosted runner. It logs in to Amazon ECR Public, builds the image, tags it with the commit SHA and `latest`, and pushes both.
2. **Deploy** runs on a self hosted runner inside my homelab. It takes the Kubernetes manifest from the repo, substitutes the commit SHA into the image tag, and applies it to the cluster.

The manifest is a three replica `Deployment` with a `Recreate` strategy and a `LoadBalancer` service. Using the SHA as the tag meant every deploy was traceable back to a commit, and `imagePullPolicy: Always` made sure the cluster picked up the new image.

The self hosted runner lived on a VM provisioned by Terraform in my [homelab](/posts/homelab-configuration-terraform-ansible-and-kubernetes-on-proxmox/). This was my first real GitOps style loop from a git push to a running pod on my own hardware.

## Update: Replaced by Hugo and GitHub Pages

This project has since been retired. The site you are reading now lives in [jstrebeck/strebeck.net](https://github.com/jstrebeck/strebeck.net) and is built with Hugo. A GitHub Actions workflow builds the site and publishes it to GitHub Pages on every push. There is no bucket, no registry, and no cluster to keep online, and hosting is free. Posts are Markdown files, which makes writing far easier than editing a hand built HTML page. The old pipeline taught me a lot, but for a personal site the simpler platform wins.
