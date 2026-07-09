# Informe Técnico: Ecosistema DevOps y Microservicios en AWS
**Asignatura:** Introducción a Herramientas Devops (ISY1101)  
**Evaluación:** Evaluación Final Transversal (EFT)  
**Institución:** Duoc UC  

---

## 1. Introducción y Objetivos
Este documento presenta el diseño, justificación y despliegue del ecosistema DevOps implementado para la plataforma transaccional de Ventas y Despachos. La solución se basa en una arquitectura de microservicios contenerizados y orquestados en la nube utilizando Amazon EKS, asegurando alta disponibilidad, escalamiento automático y despliegue continuo (CI/CD) libre de interrupciones.

---

## 2. Método de Integración del Sistema
El sistema se compone de tres capas principales con flujos de comunicación bien definidos:
1. **Frontend (React + Nginx):** Actúa como el punto de entrada para los usuarios. Para evitar problemas de CORS (Cross-Origin Resource Sharing) y mantener la seguridad interna, Nginx está configurado como **Proxy Reverso**.
2. **Backend (APIs Java Spring Boot):** 
   - **Despachos (`port 8081`):** Gestiona la lógica de envío y despacho.
   - **Ventas (`port 8082`):** Gestiona la lógica de compras.
3. **Base de Datos (MySQL 8.0):** Centraliza la persistencia de datos.

### Flujo de Comunicación:
```
[ Navegador del Cliente ]
           │
           ▼ (HTTP Port 80)
┌─────────────────────────────────┐
│     Frontend (Nginx Proxy)      │
└──────────────┬──────────────────┘
               │
       ┌───────┴───────┐ (Resolución DNS interna de Kubernetes)
       ▼               ▼
┌──────────────┐┌──────────────┐
│  Despachos   ││    Ventas    │
│ (Port 8081)  ││ (Port 8082)  │
└──────┬───────┘└──────┬───────┘
       │               │
       └───────┬───────┘ (Acceso JPA / Hibernate)
               ▼
┌──────────────────────────────┐
│      MySQL (Port 3306)       │
└──────────────────────────────┘
```

---

## 3. Contenedores y Buenas Prácticas (Docker & Compose)
Tanto el Frontend como los Backends han sido contenerizados siguiendo estándares profesionales de endurecimiento y optimización:

### Dockerfile Multietapa (Multi-stage Build):
- **Frontend y Backends** dividen el proceso en dos etapas:
  - **Etapa de Construcción (builder):** Utiliza imágenes completas de compilación (`node:20-alpine` o `maven:3.9-eclipse-temurin-21`) para instalar dependencias y construir los artefactos estáticos (`dist` o `.jar`).
  - **Etapa de Producción:** Copia únicamente el artefacto compilado a una imagen ultra ligera y minimalista (`nginx:alpine` o `eclipse-temurin:21-jre-alpine`). Esto reduce el tamaño de la imagen final en más del 70% y disminuye la superficie de vulnerabilidad.
- **Buenas Prácticas Aplicadas:**
  - Uso de `.dockerignore` para evitar subir código fuente innecesario, archivos locales o configuraciones del IDE al contexto de Docker.
  - Ejecución con usuario no-root (`appuser`) en los contenedores de Spring Boot para limitar privilegios en caso de compromiso del contenedor.
  - Declaración precisa de puertos mediante `EXPOSE` y manejo de variables de entorno para una configuración dinámica.

---

## 4. Registro de Imágenes (Amazon ECR)
Las imágenes Docker compiladas por el pipeline de CI/CD se almacenan de forma segura en **Amazon Elastic Container Registry (ECR)**:
- **Trazabilidad:** Cada imagen publicada se etiqueta con el `GIT_SHA` (el hash único del commit de GitHub que generó la compilación) además de la etiqueta `:latest`. Esto permite correlacionar de manera exacta qué versión del código se encuentra desplegada en producción.
- **Escaneo de Vulnerabilidades:** Los repositorios ECR tienen habilitada la opción `scan_on_push = true`, escaneando de forma automática cada imagen cargada para identificar dependencias obsoletas o fallos de seguridad críticos antes de su ejecución en Kubernetes.

---

## 5. Pipeline de CI/CD (GitHub Actions)
El ciclo de vida del software se automatiza completamente a través de GitHub Actions, dividido en dos pipelines:

### 1. Integración Continua (`ci.yml`) - Se ejecuta en PRs y pushes a `develop`:
- **Frontend:** Instalación de dependencias (`npm ci`), ejecución de pruebas unitarias y validación del build estático (`npm run build`).
- **Backend:** Compilación del código fuente y ejecución de pruebas unitarias automatizadas (`mvn clean test`) utilizando una base de datos H2 en memoria específica para el entorno de pruebas.

### 2. Despliegue Continuo (`cd.yml`) - Se ejecuta al fusionar en la rama `main`:
- **Autenticación segura en AWS:** Uso de credenciales IAM configuradas a través de GitHub Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).
- **Build y Push a ECR:** Compilación y carga de las imágenes Docker con etiquetas únicas del commit a ECR.
- **Despliegue con Zero Downtime:** Actualización del contexto de Kubernetes enlazando con EKS mediante `aws eks update-kubeconfig`, y aplicación de los manifiestos base (`kubectl apply -f infra/k8s/`). Las imágenes de los deployments son actualizadas dinámicamente forzando a los pods a reiniciarse de manera progresiva (rolling updates), evitando caídas del servicio.

---

## 6. Infraestructura como Código (IaC con Terraform)
Toda la infraestructura en AWS está aprovisionada de forma declarativa e inmutable mediante **Terraform** (`infra/main.tf`):
- **Redes Privadas y Públicas:** Creación de una VPC con dos subredes distribuidas en distintas zonas de disponibilidad (`us-east-1a` y `us-east-1b`) para cumplir con requisitos de redundancia.
- **Acceso a Internet:** Configuración de un Internet Gateway (IGW) y tablas de ruteo asociadas para permitir la comunicación del clúster con servicios externos de AWS.
- **EKS Cluster:** Configuración de `devops3-cluster` y sus correspondientes grupos de nodos trabajadores (Workers) utilizando instancias de tipo `t3.medium` escalables bajo demanda.

---

## 7. Configuración, Secretos y Principio de Mínimo Privilegio (IAM)
- **Roles IAM:** Para el clúster de EKS y el aprovisionamiento de nodos, se utiliza el rol pre-configurado de AWS Academy `LabRole`, el cual cuenta con permisos específicos necesarios para administrar recursos sin otorgar accesos totales innecesarios.
- **Secretos:** Las credenciales críticas del sistema (como las llaves de acceso a AWS) no están expuestas en el código fuente. Se inyectan de forma dinámica en tiempo de ejecución en GitHub Actions usando **GitHub Secrets**.
- **Variables de Entorno:** El endpoint de la base de datos, el puerto y el nombre de la BD se inyectan a los Pods de Kubernetes mediante variables de entorno en los manifiestos YAML, permitiendo que la misma imagen Docker funcione en entornos locales o de producción sin cambios de código.

---

## 8. Observabilidad
El monitoreo básico del ecosistema implementado cubre dos áreas críticas:
1. **Logs del Pipeline:** GitHub Actions registra el output detallado de cada etapa (compilación, pruebas unitarias, autenticación con AWS y comandos de despliegue).
2. **Logs del Contenedor:** Inspección en tiempo real de los logs de los contenedores a través de `kubectl logs` para verificar las trazas de Spring Boot y Nginx.
3. **Métricas de AWS CloudWatch:** Monitoreo del uso de recursos físicos (CPU y memoria RAM) en el grupo de nodos de EKS para evaluar el rendimiento general del hardware.

---

## 9. Seguridad de Red y Puertos Restringidos
- **Restricción de Puertos:** Solo el puerto `80` del servicio del Frontend (`frontend-service`) es expuesto públicamente a través de un LoadBalancer en AWS.
- **Puertos Internos (ClusterIP):** Los microservicios de `backend-despachos`, `backend-ventas` y el motor de base de datos `mysql` están configurados como servicios de tipo **ClusterIP**. Esto significa que carecen de IP pública y no pueden recibir tráfico directo desde el exterior del clúster, aislándolos de ataques externos.
- **Grupos de Seguridad (Security Groups):** Reglas de entrada y salida ultra restrictivas aplicadas a las instancias del EKS para permitir conexiones exclusivamente entre los componentes autorizados.

---

## 10. Orquestación y Escalabilidad (EKS & HPA)
- **Justificación de Amazon EKS:** Se seleccionó EKS frente a un despliegue manual (en EC2 individuales) porque ofrece abstracción de infraestructura, autocuración de contenedores (si un pod falla, Kubernetes lo recrea al instante) y una integración directa con los balanceadores de carga de AWS.
- **Escalamiento Automático (HPA):** Se configuraron recursos de tipo **Horizontal Pod Autoscaler** en Kubernetes:
  - **Frontend:** Escala dinámicamente de 1 a 5 réplicas cuando el promedio de uso de CPU supera el 50%.
  - **Backends:** Escalan de 1 a 4 réplicas cuando el promedio de uso de CPU supera el 60%.
  Esto asegura que la aplicación pueda absorber picos transaccionales de tráfico sin degradar la experiencia del usuario y optimizando costos en momentos de baja demanda.

---

## 11. Anexo: Comandos Clave para la Defensa del Proyecto
Para validar y demostrar el correcto funcionamiento del sistema en la nube o local durante la presentación, ejecute los siguientes comandos:

### 1. Validar el estado del clúster y pods:
```bash
# Listar todos los servicios levantados en Kubernetes
kubectl get svc

# Ver el estado y ubicación de todos los pods ejecutándose
kubectl get pods -o wide

# Verificar que los HPA estén activos y monitoreando la CPU
kubectl get hpa
```

### 2. Inspección de logs en caliente:
```bash
# Logs del backend de Despachos
kubectl logs -f deployment/backend-despachos-deployment --tail=100

# Logs del backend de Ventas
kubectl logs -f deployment/backend-ventas-deployment --tail=100

# Logs del Nginx de Frontend
kubectl logs -f deployment/frontend-deployment --tail=100
```

### 3. Simulación local (Docker Compose):
```bash
# Construir imágenes locales y levantar todo el ecosistema
docker-compose up --build -d

# Validar que los contenedores locales estén corriendo
docker-compose ps
```
