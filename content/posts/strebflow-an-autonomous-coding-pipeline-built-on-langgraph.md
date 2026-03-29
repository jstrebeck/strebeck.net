---
title: "StrebFlow: An Autonomous Coding Pipeline Built on LangGraph"
date: "2026-03-29T09:57:08-07:00"
author: "Josh Strebeck"
tags: ["ai", "llm", "langgraph", "python", "agents", "kubernetes", "docker"]
summary: "A LangGraph pipeline that takes a spec and acceptance scenarios, implements the change with LLM driven tools, runs the tests, and loops until the scenarios pass."
draft: false
---

Source code: [jstrebeck/strebflow](https://github.com/jstrebeck/strebflow)

StrebFlow is my take on StrongDM's Attractor concept: a non interactive coding agent that reads a spec, writes the code, and keeps iterating until a set of acceptance scenarios pass. There is no chat window. You hand it a Markdown spec and a scenarios file, point it at a repo, and check back later.

## The Pipeline

The core is a LangGraph `StateGraph` where each node is one phase of the work.

```
spec_loader -> planner -> implementer -> test_runner -> scenario_validator
                                                              |
                                                  +-----------+-----------+
                                                  v           v           v
                                               reviewer    diagnoser     done
                                                  |           |       (exhausted)
                                                  v           v
                                                done      implementer
```

The planner turns the spec into an implementation plan. The implementer is an agentic loop with tools for reading, writing, and editing files, running shell commands, listing files, and grep. The test runner executes the project's test suite in a subprocess. The scenario validator is an LLM call that reads the Given, When, Then scenarios alongside the test output and decides whether each one passes. If any fail and cycles remain, the diagnoser analyzes the failure and steers the implementer on the next attempt. On success a reviewer writes a code review and the done node writes a summary.

Every run gets an isolated workspace. The target repo is copied, and the pipeline commits a checkpoint after each node, so the full history of what the agent did is a normal git log.

## Provider and Model Routing

The LLM client works with any OpenAI compatible endpoint. Providers are declared in a YAML config with environment variable substitution, and each node can use a different model in `provider/model` form. In practice that means a cheap fast model for validation and review, and a stronger reasoning model for planning and diagnosis. The config is validated with Pydantic so a typo fails at startup rather than mid run.

## Guardrails

Autonomous loops need limits. The pipeline enforces a maximum cycle count, detects repeated tool calls within a sliding window, truncates tool output before it reaches the model, caps total context size with a middle truncation strategy, and kills test runs that exceed a timeout. A later refactor replaced a growing list of cumulative diffs in the state with a single latest diff, which cut both prompt size and the size of the checkpoint file.

## Watching It Run

The CLI renders the pipeline as a live DAG in the terminal using Rich and Unicode box drawing characters. Each stage shows its status with a spinner, elapsed time, and tool call count, and the branch and retry loop are drawn as part of the graph. It works over SSH, which matters because the runs live on my homelab cluster.

## Running It

Locally it is a Python package with a `run`, `status`, and `resume` CLI. There is a Docker Compose setup for running against a mounted repo, and Kubernetes manifests that run the pipeline as a `Job` with the config in a ConfigMap, the API key in a Secret, and the workspace on a persistent volume.

## What Is Next

The current design doc adds Claude Code as a provider. Instead of paying per token through an API, a node can spawn Claude Code as a headless subprocess with its own tools and project context, on a fixed price subscription. The provider protocol keeps the node code unchanged, so the pipeline can mix API models and Claude Code per stage.

The whole project went from design spec to working pipeline in three days, using a spec first, plan second, then implement workflow. The specs and plans are in the repo alongside the code.
