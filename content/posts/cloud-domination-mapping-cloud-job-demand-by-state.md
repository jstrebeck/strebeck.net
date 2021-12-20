---
title: "Cloud Domination: Mapping Cloud Job Demand by State"
date: "2021-12-20T12:58:28-08:00"
author: "Josh Strebeck"
tags: ["aws", "lambda", "dynamodb", "python", "serverless", "cloudfront"]
summary: "A serverless AWS project that scrapes job postings for AWS, Azure, and GCP across all 50 states and renders the dominant provider on a map."
draft: false
---

Source code: [jstrebeck/Cloud-Domination](https://github.com/jstrebeck/Cloud-Domination)

The first question most new cloud engineers ask is which of the big three platforms to learn. The usual answer is to pick whichever one has the most job postings in your area. I wanted to see that answer on a map instead of guessing, so I built Cloud Domination. It pulls job listings for AWS, Azure, and GCP in every state, stores the counts, and colors each state by the provider with the most openings.

The real goal was to have a small but complete application I could use to practice building on AWS end to end.

## Architecture

The stack is intentionally simple and mostly serverless.

- **Data collection**: A Python function built on `requests` and Beautiful Soup. I had applied for Indeed's API but sat on the waiting list for two months, so I scraped the search results page instead. The function loops over all 50 states and each of the three providers, reads the result count from the page, and writes it to the database. It runs on AWS Lambda on a schedule so the data refreshes on its own.
- **Storage**: A DynamoDB table with the state name as the partition key and one attribute per provider. The Lambda uses `update_item` with an expression like `set AWS = :p`, so each provider updates independently. Wiring Lambda to DynamoDB only needed an IAM role with access to both, which was a big time saver compared to running a database server.
- **Frontend**: A static page using the Google Maps JavaScript API. Maps has no built in way to select a state, so each state is drawn as a polygon from latitude and longitude coordinates. A script reads the per state counts, picks the highest, and fills the polygon orange for AWS, blue for Azure, or yellow for GCP.
- **Hosting**: Nginx on an EC2 t2.micro behind an Elastic Load Balancer. CloudFront sits in front as the CDN with a certificate from AWS Certificate Manager for clouddomination.net. Because the data changes on a schedule, the cache is invalidated whenever the database is refreshed.

Later I added a Dockerfile that packages the site into the official Nginx image so it can run anywhere a container runs.

## What I Learned

The result was not surprising. AWS led in every single state. The more useful lessons were about the approach itself. Scraping a results page is fragile, and a raw count of postings that mention a keyword is a noisy signal for real demand. If I revisit this I would use a proper API and track the numbers over time to see whether the gap between providers closes.

Even with those flaws, the project covered scheduling, serverless compute, a NoSQL datastore, IAM, load balancing, CDN caching, and TLS in one small package. That was the point.
