---
title: "Contribute to the aws Terraform Provider"
date: "2024-12-07T13:29:25-08:00"
tags: ["aws", "devops", "terraform"]
---

# Configure Development Environment
- Install Terraform and go
    - I used the version in the default Ubuntu apt repos
- Using ZSH
    - If you are using zsh I recommend adding the following line to your `.zshrc`
    ```export PATH="$PATH:$(go env GOPATH)/bin"```
    - [Credits to mmik in this post](https://stackoverflow.com/questions/42614380/go-install-not-working-with-zsh)
