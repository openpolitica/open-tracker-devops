# DevOps para proyecto Open Tracker de OpenPolitica

Este repositorio cuenta con un conjunto de ficheros para la integración,
distribución e implementación de diferentes componentes del proyecto Open
Tracker desarrollado por Open Politica.

## Estructura de directorios
El proyecto cuenta con dos entornos de desarrollo: staging y producción, el
primero orientado para efectuar las pruebas de desarrollo mientras que el
segundo para su uso por los usuarios.

En el servidor, la estructura de directorios es la siguiente:

```
$HOME (Ejemplo: /home/ubuntu)
 |- congreso (root del proyecto, por defecto: congreso)
 |  |- devops/ (este repositorio)
 |  |  |- nginx-proxy (alojamiento de proxy reverso)
 |  |  |- other files/folders
 |  |- staging/
 |  |  |- database/
 |  |  |  |- dbfiles
 |  |  |- backend/
 |  |  |  |-(repositorio backend)
 |  |- production/
 |  |  |- database/
 |  |  |  |- dbfiles
 |  |  |- backend/
 |  |  |  |-(repositorio backend)
```

## Instalación
Los scripts ubicados en este repositorio no requieren de una instalación
propiamente, solamente del clonado del repositorio, que se sugiere sea en la
carpeta del proyecto:
```
ssh -i ./id_rsa user@ipaddress
cd congreso
git clone https://github.com/openpolitica/devops.git
cd devops
```

## Uso

### Desplegar entorno de desarrollo local


Se tiene unos scripts especiales para el desarrollo local, el cual solamente
despliega la base de datos, puesto que se entiende que en el desarrollo local,
se realiza el despliegue del backend desde el repositorio local.
```
cd backend
docker-compose -f docker-compose.local.yml up -d
```

```
cd ../database
ENV_TYPE=local ./deploy-db-all.sh
```


## Licencia

Copyright 2021 OpenPolitica

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	 http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
