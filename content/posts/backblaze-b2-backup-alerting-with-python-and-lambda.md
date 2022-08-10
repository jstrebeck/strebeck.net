---
title: "Backblaze B2 Backup Alerting With Python and Lambda"
date: "2022-08-10T09:29:15-07:00"
author: "Josh Strebeck"
tags: ["python", "aws", "lambda", "backblaze", "backups", "docker"]
summary: "A small Python tool that checks whether the newest object in a Backblaze B2 bucket is older than 24 hours, runnable locally, in Docker, or as a scheduled Lambda."
draft: false
---

Source code: [jstrebeck/B2-Alerting](https://github.com/jstrebeck/B2-Alerting)

Backups fail quietly. A job stops running, nothing errors out loud, and you only find out when you need a restore. I push backups to a Backblaze B2 bucket and wanted a check that would tell me when new files stopped showing up.

## How It Works

The script uses the official `b2sdk` library. It authorizes with an application key, opens the bucket by name, lists the bucket with `latest_only=True`, and reads the upload timestamp of the newest file. If that timestamp is more than 24 hours old, the backup is considered stale.

That is the whole check. The interesting part is that the same logic is packaged three ways.

- **Local**: Credentials come from a `.env` file loaded with `python-dotenv`. Run `./main.py my-bucket` and it prints a pass or fail line.
- **Docker**: A `python:3.9` image installs the requirements and sets the script as the entrypoint. The bucket name is passed as the container argument.
- **AWS Lambda**: A `lambda_function.py` variant reads credentials from environment variables and takes the bucket name as the event payload. Dependencies are vendored with `pip install --target` and zipped alongside the handler.

## Scheduling and Notifications

For the Lambda version, an EventBridge rule runs the function once a day with a constant input of the bucket name. Instead of adding SNS code to the function, I used a Lambda destination with the condition set to "On success" and pointed it at SNS. The function only returns a successful result when the backup is stale, so the destination fires only when there is something worth reading. On a healthy day nothing is sent.

## Takeaways

This was a good exercise in keeping a tool small and letting the platform handle scheduling and delivery. The compute, the trigger, and the notification are all separate managed pieces, and the Python code stays focused on one question: when did the last backup land?
