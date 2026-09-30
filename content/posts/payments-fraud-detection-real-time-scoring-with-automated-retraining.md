---
title: "Payments Fraud Detection: Real-Time Scoring With Automated Retraining on Kubernetes"
date: "2026-09-30T12:19:20-07:00"
author: "Josh Strebeck"
tags: ["mlops", "kubernetes", "kserve", "mlflow", "python", "fastapi", "argocd", "prometheus", "grafana", "homelab"]
summary: "A synthetic payments platform that scores every transaction for fraud in real time, with training, registry, serving, monitoring, and alert-driven retraining automated end to end on my homelab. Including the drill where the traffic drifted and nobody touched anything."
draft: false
---

Source code: [jstrebeck/payments-fraud-detection](https://github.com/jstrebeck/payments-fraud-detection)

I wanted to take what I know from working in payments and build something at home that covers the whole model lifecycle end to end, and that I can break on purpose. So this project is a small payments platform with a deliberately thin business rule and a lot of machinery around the model: a FastAPI service that scores every payment, LightGBM models tracked and registered in MLflow, KServe serving the current champion, Prometheus and Grafana watching the model as closely as the service, and a retraining loop that reacts to drift and can only promote through an evaluation gate. All of it runs on the [homelab](/posts/homelab-configuration-terraform-ansible-and-kubernetes-on-proxmox/) and is delivered by Argo CD. The data is synthetic and the cards are opaque tokens, so nothing here is in PCI scope.

![Architecture: simulator, payments API, KServe predictor, Postgres, drift monitor and retrain CronJob in the fraud namespace, with MLflow, SeaweedFS, Prometheus, Grafana, and Argo CD on the platform](/images/fraud-architecture.svg)

## How a Payment Is Scored

A simulator generates deterministic customers, merchants, cards, and transactions from a seed, injects fraud through explicit patterns like card testing bursts and impossible travel, and replays them against the API at a steady rate. The API validates the transaction, loads the card's recent history from Postgres, and builds a feature vector. Then it calls the KServe predictor over the V2 inference protocol with a 300 millisecond budget. If the model times out, errors, or reports a feature version the API does not understand, the payment is scored by a rule-based fallback and a counter records why. No payment is ever left undecided. The score maps to approved, review, or declined, and the decision, score, model version, and features are written to Postgres.

Labels arrive later. The simulator posts chargebacks for fraud and confirmations for a sample of legitimate payments a few minutes after scoring, imitating the delay a real platform sees. Those labels are the training data for retraining, and they also drive live precision and recall metrics against the simulator's ground truth. One correlation ID follows a payment from the simulator through the API and the predictor into Postgres, so a single decision can be traced across every hop.

## One Feature Definition

The model's input is the feature vector, not the raw transaction. History-based features like the card's transaction count over seven days cannot live inside a stateless model, so the same pure feature functions run in training and in the API, and every registered version is tagged with the feature version it was trained on. The API checks that tag the first time it sees a new version in a response and falls back to rules if they disagree. Retraining goes further and uses the feature vectors the API stored when it scored the payments, so online and offline parity is exact rather than recomputed.

## Serving by Alias

KServe runs in Standard mode, so each InferenceService is a plain Deployment with no Knative or Istio. The stock MLServer runtime could not load an MLflow 3 model, so the serving runtime is a custom MLServer image with the model's pinned requirements. The InferenceService points at `models:/fraud-detector@champion`, and a storage initializer I added to the homelab resolves the alias against MLflow at pod start and downloads the model through the artifact proxy with no S3 credentials.

That makes promotion simple. The gate moves the champion alias, then patches an annotation on the predictor pod, which KServe turns into a rolling update. Git does not change, and Argo CD leaves the annotation alone because it was never declared. Each version also carries its recommended review and decline thresholds as registry tags, so the API decides with thresholds that belong to the model it is actually serving instead of values fixed in a config file.

## Watching the Model

Every workload ships a ServiceMonitor, and the metrics are about the model as much as the service. A score histogram gives a drift signal without labels. Flagged share is compared with its own 24 hour band. Precision and recall are PromQL over the delayed label counter. A registry exporter turns MLflow versions and aliases into metrics for a training dashboard. A drift monitor computes the population stability index of the last hour of live feature vectors against the champion's training profile every five minutes, running as a long-lived exporter so Prometheus can scrape it without a Pushgateway. Four Grafana dashboards live in the repo as ConfigMaps and are provisioned by Argo CD, and every alert links to a runbook.

## The Drill

The point of building all that was to see it work without me. On September 30 I switched the simulator to a drifted traffic profile with one commit: inflated amounts, more e-commerce, and a new session hijack fraud pattern the champion had never seen.

![Grafana drift dashboard during the drill, PSI per feature rising from about 07:00 with alert regions](/images/fraud-grafana-fraud-drift.jpg)

The drift alert fired at 07:54 on the amount and channel features. On the model dashboard, precision and recall against ground truth fell as the new fraud arrived, while scoring latency stayed flat at about 17 milliseconds.

![Grafana model dashboard during the drill: score heatmap, flagged share against its band, decisions per minute, latency, and precision and recall against simulator truth](/images/fraud-grafana-fraud-model.jpg)

Every 30 minutes a CronJob asks Prometheus whether the drift alert is firing. At 08:00 it retrained on a small generated history plus every labelled live payment from the last week, and the gate rejected the result. That was a real finding. The first version split live labels by time, so an hour into the drift every drifted label sat in the validation and test sets and the challenger never trained on the new pattern. I changed the split to hash by card, which keeps a whole fraud incident on one side, and required at least 50 frauds in the test set. At 10:00 the next run trained version 6 and the gate promoted it, with PR-AUC on held-out live cards going from 0.42 to 0.64. The Job rolled the predictor, and the API switched to version 6 and its thresholds. Every verdict is recorded as tags on the version.

![MLflow registry showing fraud-detector versions with retrain trigger, gate outcome, gate reason, and recommended thresholds as tags](/images/fraud-mlflow-registry.jpg)

Afterward I reverted the drift commit and put the old champion back with the rollback runbook. It took 18 seconds.

## What the Drill Got Wrong

Two things came out of it that I would not have found without running it. First, version 6 was the better model for the drifted world but partly forgot the card testing pattern, because the held-out live cards held too few of those frauds for the gate to notice. The fix I have in mind is a second gate check on a generated benchmark that covers every known pattern.

Second, a few hours later the drift alert fired again on normal traffic and the 18:00 run promoted a worse model. The alert had been counting card history features, which swing every time the simulator starts a pass with fresh cards, and the gate was testing on seven days of labels that still contained the drift. The alert now counts population features only, the simulator's world grew so passes take longer, and the gate tests on held-out cards from the last six hours, which rejects that promotion when replayed on the real labels. All of it is written up in an architecture decision record with the numbers.

## Delivery

Platform components live in the homelab repo and this repo holds only its own workloads, so a reader of either sees one job done end to end. Argo CD syncs the homelab overlay with prune and self-heal, image tags are git SHAs, and a code deploy is a tag-bump commit that the release script makes. CI runs lint, strict type checks, tests, and a render of the manifests on GitHub-hosted runners so nothing in the pull request path needs LAN access. The image build and cluster training workflows target a self-hosted runner that is not registered yet, so for now those two steps run by hand with the same scripts.

The repo has fifteen decision records, a runbook for every alert, a model card template filled in for each version, and a demo script that replays the drill against the live cluster. That documentation is as much the point as the code.
