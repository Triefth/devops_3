El archivo de configuración .github/workflows/cd.yml automatiza todo el ciclo de entrega. Cada interacción con la rama principal ejecuta de forma transparente:

Autenticación nativa y segura en AWS mediante el uso de GitHub Secrets (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN).

Inicio de sesión automatizado en Amazon ECR.

Compilación de código fuente y empaquetamiento en imágenes Docker utilizando la política imagePullPolicy: Always.

Publicación de artefactos en el registro privado.

Actualización de los Deployments de Kubernetes mediante un despliegue controlado sin interrupción del servicio.

Autor Daniel Eduardo Cifuentes Huenten - Estudiante de Ingeniería / Automatización DevOps - Duoc UC
