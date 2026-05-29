<h1 align="center">FastAPI Service</h1>
<p align="center"> <i>CI/CD API with deployment via Argo CD</i></p>

## Summary



This repository demonstrates an **end-to-end automated deployment pipeline**.  
With each push or merge into the `main` branch, a Docker image is built and published to Docker Hub.

The CI/CD pipeline automatically opens a **Pull Request** in the manifest repository, updating the application image. After approval, ArgoCD synchronizes the changes directly into the Kubernetes cluster.

---

### Requirements

* DockerHub account  
* GitHub account  
* Kubernetes cluster (Rancher Desktop, Minikube, or Kind)

---

### Additional Information

> If you are going to use this repository, start with the _manifest repository_. It is essential for the workflow.
>
> [![GitHub Pages](https://img.shields.io/badge/FastApi%20Service%20Manifests-121013?style=for-the-badge&logo=github&logoColor=white)](https://github.com/alexsandroocanha/FastApi-Service-Manifests)

---

### Topics

* [Overview](#overview)
* [Repository Structure](#repository-structure)
* [Configure GitHub Actions Secrets](#secret-token-configuration-github-actions)
* [How to run the application](#how-to-run-the-application)
* [Workflow Configuration](#workflow-configuration)
  * [Job - Build Image](#build)
  * [Job - Push to Docker Hub](#dockerhub)
  * [Job - Deploy Manifests](#deploy)

---

## Fast Links

- CI/CD: `./.github/workflows/deploy.yml`  
- Dockerfile: `./Dockerfile`  
- Manifests Repository: https://github.com/alexsandroocanha/FastApi-Service-Manifests  

---

## Overview

This repository contains a **FastAPI microservice**, containerized with Docker and integrated into a **GitHub Actions CI/CD pipeline**.

---

## Repository Structure

This project is divided into 2 repositories:

### 1. Application & CI/CD
Contains the FastAPI code, Dockerfile, and GitHub Actions workflow.

```bash
├─ .github/workflows/deploy.yml
├─ main.py
├─ requirements.txt
└─ Dockerfile
````

![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge\&logo=python\&logoColor=ffdd54)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge\&logo=docker\&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge\&logo=githubactions\&logoColor=white)

---

### 2. Kubernetes Manifests & ArgoCD

Contains Kubernetes manifests and ArgoCD configuration.

```bash
├─ ArgoCD/
│  └─ argocd.yml
├─ k8s/
│  └─ base-k8s.yml
├─ deployment-v1.yaml
└─ README.md
```

![ArgoCD](https://img.shields.io/badge/ArgoCD-0D80D8?style=for-the-badge\&logo=argo\&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge\&logo=kubernetes\&logoColor=white)

---

## How to run the application

First, clone this repository:

```bash
git clone https://github.com/alexsandroocanha/FastApi-Service
```

Change the remote repository if needed:

```bash
git remote set-url origin <new_url>
```

---

## Secret Token Configuration (GitHub Actions)

Add the following environment variables:

| Name            | Required | Description                        |
| --------------- | -------- | ---------------------------------- |
| DOCKER_PASSWORD | yes      | Docker Hub access token            |
| DOCKER_USERNAME | yes      | Docker Hub username                |
| SSH_KEY         | yes      | SSH private key for Git access     |
| REPO_GIT        | yes      | URL of the external Git repository |

---

## Workflow Configuration

The workflow is divided into 2 main jobs: build and deploy.

---

### Build

```yaml
Build:
  runs-on: ubuntu-latest
  environment: Docker
  steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Login to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}

    - name: Build and push image
      uses: docker/build-push-action@v6
      with:
        context: .
        file: ./Dockerfile
        push: true
        tags: |
          user/app-name:deploy-${{ github.sha }}
          user/app-name
```

---

### Docker Hub

Images published on Docker Hub follow this naming convention:

<img
height="300"
src="imagens/image.png">

---

### Deploy

This job is responsible for updating the Kubernetes manifests in the second repository.

The deployment is performed by generating a new manifest and creating a Pull Request.

```yaml
Deploy:
  runs-on: ubuntu-latest
  needs: Build
  environment: Docker
  steps:
    - name: Create working directory
      run: mkdir ~/repo

    - name: Add SSH key
      uses: webfactory/ssh-agent@v0.9.0
      with:
        ssh-private-key: ${{ secrets.SSH_KEY }}

    - name: Clone manifest repository
      run: git clone ${{ secrets.REPO_GIT }} ~/repo

    - name: Generate Kubernetes manifest
      run: |
        cat > ~/repo/deployment-v1.yaml <<EOF
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: hello-api
          namespace: argocd
          labels:
            app: hello-api
        spec:
          strategy:
            type: RollingUpdate
            rollingUpdate:
              maxUnavailable: 100%
              maxSurge: 0
          revisionHistoryLimit: 1
          replicas: 3
          selector:
            matchLabels:
              app: hello-api
          template:
            metadata:
              labels:
                app: hello-api
            spec:
              containers:
                - name: hello-api
                  image: user/app-name:deploy-${{ github.sha }}
                  ports:
                    - containerPort: 8000
                  readinessProbe:
                    httpGet:
                      path: /
                      port: 8000
                    initialDelaySeconds: 5
                    periodSeconds: 10
                  livenessProbe:
                    httpGet:
                      path: /
                      port: 8000
                    initialDelaySeconds: 10
                    periodSeconds: 20
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: hello-api
          namespace: argocd
        spec:
          type: NodePort
          selector:
            app: hello-api
          ports:
            - name: http
              port: 8000
              targetPort: 8000
              nodePort: 30080
        EOF

    - name: Create Pull Request
      run: |
        cd ~/repo
        git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git config --global user.name "github-actions[bot]"
        BRANCH="chore/new-manifest-${GITHUB_SHA::7}"
        git checkout -b "$BRANCH"
        git add .
        git commit -m "chore: update deployment manifest ${GITHUB_SHA::7}"
        git push -u origin "$BRANCH"
```

---

## Final Considerations

This is the first repository. To continue, refer to the second repository:

[![GitHub Pages](https://img.shields.io/badge/FastApi%20Service%20Manifests-121013?style=for-the-badge\&logo=github\&logoColor=white)](https://github.com/alexsandroocanha/FastApi-Service-Manifests)

---

## Contact Information

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge\&logo=linkedin\&logoColor=white)](https://www.linkedin.com/in/alexsandro-ocanha-rodrigues-77149a35b/)
[![Instagram](https://img.shields.io/badge/Instagram-E4405F?style=for-the-badge\&logo=instagram\&logoColor=white)](https://www.instagram.com/alexsandro.pcap/)
[![Gmail](https://img.shields.io/badge/Gmail-D14836?style=for-the-badge\&logo=gmail\&logoColor=white)](mailto:alexsandroocanha@gmail.com)
