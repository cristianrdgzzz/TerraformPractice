# Module Example — Webserver Cluster

Summary
-------
This directory contains an example Terraform module named
`modules/services/webserver-cluster` that provisions a small web server
cluster on AWS composed of:

- An Application Load Balancer (ALB) listening on port 80
- A Target Group with health checks
- An Auto Scaling Group (ASG) that launches EC2 instances using a Launch Template
- A small `user-data` script that starts a minimal web server (busybox httpd)

The repository also includes environment-specific example folders (`prod`,
`stage`) that demonstrate how to consume the module (wrappers).

Contenido importante
---------------------

- `modules/services/webserver-cluster/` — Código del módulo (recursos principales)
- `prod/services/webserver-cluster/` — Ejemplo de wrapper para producción
- `stage/services/webserver-cluster/` — Ejemplo de wrapper para staging
- `modules/services/webserver-cluster/ARCHITECTURE.md` — Diagramas y flujo

Requisitos previos
------------------

- Tener instalado `terraform` (1.x compatible). Verifique con `terraform version`.
- Tener credenciales de AWS configuradas (perfil o variables de entorno).
- Antes de desplegar el módulo, debe desplegar la base de datos MySQL que
  provee la información consumida por el módulo (remote state). El ejemplo
  asume que el stack de la base de datos se encuentra en
  `data-stores/mysql` y que su estado remoto está en un bucket S3.

Flujo recomendado (paso a paso)
-------------------------------

1. Abrir PowerShell y navegar al folder del ejemplo que desea ejecutar.

   Por ejemplo, para `stage`:

```powershell
cd 'c:\Users\PE2610\Desktop\Apuntes\Apuntes Terraform\TerraformTutorial\code\terraform\04-terraform-module\module-example\stage\services\webserver-cluster'
```

2. (Opcional pero recomendado) Formatee y valide los ficheros del módulo:

```powershell
cd '..\..\..\modules\services\webserver-cluster'
terraform fmt
terraform validate
```

3. Desplegar la base de datos (si aún no está desplegada).

```powershell
cd '..\..\..\prod\data-stores\mysql'  # o la ruta correspondiente
terraform init
terraform apply
```

4. Configurar en el wrapper (prod/stage) las variables que apuntan al estado
   remoto de la base de datos (`db_remote_state_bucket` y
   `db_remote_state_key`) en su `variables.tf` o pasando `-var`/`-var-file`.

5. Inicializar y aplicar la configuración del entorno (ejemplo `stage`):

```powershell
cd '...\module-example\stage\services\webserver-cluster'
terraform init
terraform plan -out plan.stage
terraform apply 'plan.stage'
```

6. Verificar el resultado — el `apply` mostrará la salida `alb_dns_name`.
   Pruebe el ALB con `curl` o un navegador:

```powershell
curl http://<alb_dns_name>/
```

7. Para `prod` siga el mismo flujo dentro de
   `prod/services/webserver-cluster` (ajuste el tamaño de instancias y
   el `db_remote_state` según corresponda).

Limpieza
---------

Para eliminar los recursos creados por el wrapper del entorno:

```powershell
terraform destroy
```

Notas y recomendaciones
-----------------------

- El AMI usado en el módulo es un ejemplo; reemplace `image_id` por una
  variable o use `data "aws_ami"` para seleccionar la AMI apropiada por
  región/plataforma.
- Para entornos reales: restrinja las reglas de los Security Groups (no
  deje `0.0.0.0/0` salvo que sea necesario) y utilice TLS en el ALB.
- Considere usar `aws_launch_template` (ya aplicado) y versiones para
  controlar los cambios en configuración de instancia.
- Si usa este repo en múltiples equipos, comparta un `backend` remoto
  (S3 + DynamoDB) para el estado y bloqueos.

Diagrama rápido (visualmente):

```mermaid
flowchart LR
  User --> ALB[ALB (port 80)]
  ALB --> TG[Target Group]
  TG --> ASG[Auto Scaling Group]
  ASG --> EC2[EC2 Instances]
  EC2 --> DB[(MySQL DB - separate stack)]
```

Dónde buscar ayuda
-------------------

- Ver `modules/services/webserver-cluster/README.md` para documentación
  específica del módulo y `ARCHITECTURE.md` para diagramas detallados.
- Revisar los ficheros `prod/...` y `stage/...` como ejemplos de uso en
  entornos.

Si quieres, puedo:
- Ejecutar `terraform fmt` en los folders que actualicé ahora.
- Reemplazar el `image_id` por un `variable`+`data "aws_ami"` lookup.
- Añadir archivos `example.tfvars` para `prod` y `stage`.
