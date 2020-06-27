# Reubicado

Movido a https://gitlab.com/glalejos/docker-firefox-dnie.

# dnie.sh
Programa de gestión de navegador para uso de DNI electrónico español

## Introducción
`dnie.sh` es un programa Bash que automatiza la creación y configuración de un contenedor Docker con Firefox para el acceso a páginas web que permiten el uso del DNI electrónico español. También se incluye un fichero `Dockerfile`, necesario para la construcción de la imagen de Docker.
Uno de los fundamentos de este programa es la **transparencia**. No se incluye ningún fichero binario, todo el proceso de provisión está expresado en el programa `dnie.sh` y fichero `Dockerfile`, lo que permite auditar su funcionamiento.

## Uso
### Requisitos
Es necesario tener Docker instalado. Si no tienes una licencia de empresa, puedes usar la [versión de comunidad](https://www.docker.com/community-edition). Recuerda que el usuario con el que ejecutes el programa `dnie.sh` necesitará tener permisos para construir la imágen Docker y ejecutar el contenedor.

### Construcción del contenedor
`dnie.sh construir`

### Ejecución del navegador
`dnie.sh navegador`
