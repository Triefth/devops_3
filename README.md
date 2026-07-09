#  Ecosistema DevOps: Arquitectura de Microservicios en AWS

[![AWS EKS](https://img.shields.io/badge/Amazon_AWS-EKS_%26_ECR-FF9900?logo=amazonaws&logoColor=white)](#)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-Orquestación-326CE5?logo=kubernetes&logoColor=white)](#)
[![CI/CD](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions&logoColor=white)](#)
[![React](https://img.shields.io/badge/React-Frontend-61DAFB?logo=react&logoColor=black)](#)
[![Spring Boot](https://img.shields.io/badge/Spring_Boot-Backend-6DB33F?logo=spring&logoColor=white)](#)

## 📋 Descripción General

Este repositorio contiene la definición completa de infraestructura, orquestación y código fuente para un sistema de microservicios transaccional. El proyecto implementa un flujo de trabajo **DevOps** moderno, garantizando despliegues automatizados, infraestructura inmutable y alta disponibilidad en la nube de Amazon Web Services (AWS).

La solución soporta las operaciones de un sistema de Ventas y Despachos, integrando un frontend interactivo, APIs robustas y persistencia de datos segura, todo gestionado bajo un pipeline de Integración y Entrega Continua (CI/CD).

---

##  Arquitectura y Tecnologías

El ecosistema está diseñado para ser tolerante a fallos y altamente escalable:

```mermaid
graph TD
    subgraph Cliente ["Entorno de Cliente"]
        Browser["Navegador Web (Usuario)"]
    end

    subgraph GitHub ["Repositorio y CI/CD"]
        GHA["GitHub Actions Pipeline"]
    end

    subgraph AWS ["Nube AWS (us-east-1)"]
        subgraph ECR ["Amazon Elastic Container Registry"]
            ECR_F["Repo: devops-frontend"]
            ECR_D["Repo: devops-back-despachos"]
            ECR_V["Repo: devops-back-ventas"]
        end

        subgraph VPC ["VPC (10.0.0.0/16)"]
            subgraph EKS ["Amazon EKS Cluster (devops3-cluster)"]
                
                %% Servicios de Kubernetes
                SVC_F["frontend-service (LoadBalancer Port 80)"]
                SVC_D["backend-despachos (ClusterIP Port 8081)"]
                SVC_V["backend-ventas (ClusterIP Port 8082)"]
                SVC_M["mysql (ClusterIP Port 3306)"]

                %% Pods de Kubernetes
                subgraph Pods_F ["Pods Frontend (React + Nginx)"]
                    Pod_F1["frontend-pod"]
                end
                
                subgraph Pods_D ["Pods Backend Despachos"]
                    Pod_D1["backend-despachos-pod"]
                end

                subgraph Pods_V ["Pods Backend Ventas"]
                    Pod_V1["backend-ventas-pod"]
                end

                subgraph Pods_M ["Pod Base de Datos (MySQL 8.0)"]
                    Pod_M1["mysql-pod"]
                end

                %% HPA
                HPA_F["frontend-hpa"] -->|Autoscaling CPU >50%| Pods_F
                HPA_D["backend-despachos-hpa"] -->|Autoscaling CPU >60%| Pods_D
                HPA_V["backend-ventas-hpa"] -->|Autoscaling CPU >60%| Pods_V
            end
        end
    end

    %% Relaciones de comunicación (Tráfico HTTP/API)
    Browser -->|1. Carga SPA & Recursos Estáticos| SVC_F
    SVC_F --> Pod_F1
    
    Browser -->|2. Llama APIs /api/v1/...| SVC_F
    Pod_F1 -->|Proxy Nginx: /api/v1/despachos| SVC_D
    Pod_F1 -->|Proxy Nginx: /api/v1/ventas| SVC_V

    SVC_D --> Pod_D1
    SVC_V --> Pod_V1

    Pod_D1 -->|Acceso JPA| SVC_M
    Pod_V1 -->|Acceso JPA| SVC_M
    SVC_M --> Pod_M1

    %% Flujo CI/CD
    GHA -->|Construye e Inyecta Imágenes| ECR
    GHA -->|Actualiza Manifiestos K8s| EKS
    ECR_F -.->|Pull Image| Pod_F1
    ECR_D -.->|Pull Image| Pod_D1
    ECR_V -.->|Pull Image| Pod_V1
```

* **Infraestructura como Código (IaC):** Aprovisionamiento automatizado de VPCs, Subredes y el clúster principal utilizando **Terraform**.
* **Orquestación de Contenedores:** Gestión centralizada de microservicios mediante **Amazon EKS** (Elastic Kubernetes Service).
* **Registro de Imágenes:** Almacenamiento privado y seguro de artefactos Docker en **Amazon ECR**.
* **Autoscalado Dinámico:** Implementación de Horizontal Pod Autoscaler (HPA) en Kubernetes para escalar réplicas basándose en umbrales de CPU (>60%).
* **Frontend:** Aplicación interactiva construida con **React**.
* **Backend:** Microservicios independientes desarrollados con **Java Spring Boot** (API REST Ventas y API REST Despachos).
* **Base de Datos:** Motor relacional **MySQL** desplegado internamente en el clúster con volúmenes persistentes.

---

##  Requisitos Previos del Sistema

Para ejecutar, modificar o desplegar este proyecto en un nuevo entorno, se requiere la instalación de las siguientes herramientas:

* Git CLI
* Docker Desktop (con el clúster local de Kubernetes habilitado)
* Terraform CLI (v1.0.0 o superior)
* AWS CLI configurado con credenciales válidas
* Kubectl configurado para la versión correspondiente del clúster EKS

---

##  Guía de Despliegue (AWS EKS)

Siga estos pasos estructurados para aprovisionar y desplegar el sistema completo en la nube.

### 1. Autenticación de AWS
Configure las variables de entorno en su terminal con credenciales válidas (formato PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID="SU_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY="SU_SECRET_KEY"
$env:AWS_SESSION_TOKEN="SU_SESSION_TOKEN"

2. Aprovisionamiento de Infraestructura
Levante los recursos base (VPC, EKS, ECR) ejecutando Terraform en el directorio correspondiente:
cd infra
terraform init
terraform apply

3. Configuración del Contexto de Kubernetes
Enlace su terminal local con el clúster recién creado en AWS:
aws eks update-kubeconfig --region us-east-1 --name devops3-cluster
kubectl apply -f infra/k8s/

Integración y Entrega Continua (CI/CD)
El proyecto cuenta con un pipeline automatizado definido en .github/workflows/cd.yml. Cada integración de código a la rama principal (main) dispara el siguiente flujo:

Validación de credenciales inyectadas de forma segura vía GitHub Secrets.

Autenticación automática con el registro de Amazon ECR.

Compilación nativa y empaquetado de los tres microservicios en imágenes Docker (:latest).

Publicación segura de los artefactos en la nube.

Actualización continua de los pods en el clúster EKS asegurando una transición sin interrupciones (Zero Downtime Deployment).
Comandos Operativos y de Monitoreo
Para validar la salud del sistema o realizar troubleshooting, utilice las siguientes instrucciones:

Validar el estado de los microservicios: kubectl get pods

Consultar el balanceador de carga y obtener la URL pública: kubectl get svc frontend-service

Revisar métricas de escalamiento automático: kubectl get hpa

Extraer logs de un contenedor específico: kubectl logs -f <nombre-del-pod>
Autor
Daniel Eduardo Cifuentes Huenten
Ingeniería y Desarrollo Full-Stack | Arquitectura DevOps
