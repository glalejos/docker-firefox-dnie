#    Programa de gestión de navegador para uso de DNI electrónico.
#    Copyright (C) 2017  Guillermo López Alejos
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Seleccionar imagen base de Docker
ARG DEBIAN_V
FROM debian:${DEBIAN_V}

###############################################################################
# DESCARGA E INSTALACIÓN DE PAQUETES
###############################################################################

# APT
#####
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update

# Instalar utilidades:
# * locales: Ver https://wiki.debian.org/Locale
RUN apt-get install -y apt-utils locales sudo

# [1] Localización
RUN	echo "es_ES.UTF-8 UTF-8" > /etc/locale.gen && \
	echo "es_ES.UTF-8 UTF-8" > /etc/default/locale && \
	locale-gen es_ES.UTF-8 && \
	dpkg-reconfigure locales

ENV LANGUAGE es_ES.UTF-8
ENV LANG es_ES.UTF-8
ENV LC_ALL es_ES.UTF-8
ENV LC_CTYPE es_ES.UTF-8

# Instalar Firefox y paquetes relacionados:
# * firefox-esr-l10n-es-es: localización en español. Ver [1].
# * libnss3-tools: acceso a "modutil" para modificar la base de datos secmod.db y "certutil" para gestionar la base de datos cert8.db.
# * xvfb: para ejecutar Firefox en el proceso de construcción sin interfaz gráfica.
RUN apt-get install -y firefox-esr firefox-esr-l10n-es-es libnss3-tools xvfb

# Instalar programas de gestión de tarjetas inteligentes.
RUN apt-get install -y pcscd pcsc-tools pinentry-qt pinentry-qt4 opensc opensc-pkcs11

# Programa de gestión de DNIe y navegador
#########################################
ARG DOCKER_PROGRAMAS_DIR
ARG DOCKER_FIREFOX_TRAZAS_DIR
ARG PROGRAMA_DNIE_FICHERO
ENV PROGRAMA_DNIE_ABS ${DOCKER_PROGRAMAS_DIR}/${PROGRAMA_DNIE_FICHERO}

RUN	mkdir -p ${DOCKER_PROGRAMAS_DIR}
COPY ["${PROGRAMA_DNIE_FICHERO}", "${DOCKER_PROGRAMAS_DIR}/"]
RUN	chown -R "${USUARIO}:${USUARIO}" "${DOCKER_PROGRAMAS_DIR}" && \
	find "${DOCKER_PROGRAMAS_DIR}" -type f | xargs chmod u+x

# PROGRAMAS OFICIALES DNIe Y CERTIFICADOS
#########################################

ENV DOCKER_DESCARGAS_DIR ${DOCKER_PROGRAMAS_DIR}/descargas
RUN mkdir -p "${DOCKER_DESCARGAS_DIR}"

ARG PAQUETE_DESCARGAS_NOMBRE
ADD "${PAQUETE_DESCARGAS_NOMBRE}" "${DOCKER_DESCARGAS_DIR}"


# Con 'apt-get -y -f install' nos aseguramos de que no quedan dependencias incumplidas.
ARG PKCS11_FICHERO
RUN	dpkg -i "${DOCKER_DESCARGAS_DIR}/${PKCS11_FICHERO}" && \
	apt-get -y -f install

###############################################################################
# CONFIGURACIÓN
###############################################################################

# Entorno de usuario
####################

# Nombre del usuario. Debe coincidir con el nombre del usuario del sistema.
ARG USUARIO
ARG USUARIO_UID
ARG USUARIO_GID
ARG USUARIO_CASA=/home/${USUARIO}

# Preparar entorno del usuario
RUN	mkdir -p ${USUARIO_CASA} && \
	chown ${USUARIO_UID}:${USUARIO_GID} -R ${USUARIO_CASA} && \
	echo "${USUARIO}:x:${USUARIO_UID}:${USUARIO_GID}:${USUARIO},,,:${USUARIO_CASA}:/bin/bash" >> /etc/passwd && \
	echo "${USUARIO}:x:${USUARIO_UID}:" >> /etc/group && \
	mkdir -p ${DOCKER_FIREFOX_TRAZAS_DIR} && \
	chown ${USUARIO_UID}:${USUARIO_GID} ${DOCKER_FIREFOX_TRAZAS_DIR} && \
	chown ${USUARIO_UID}:${USUARIO_GID} ${PROGRAMA_DNIE_ABS} && \
	adduser ${USUARIO} sudo && \
	echo "root ALL=(ALL) ALL\n\
${USUARIO} ALL=(ALL) NOPASSWD: ALL\n\
Defaults    env_reset\n\
Defaults    secure_path=\"${DOCKER_PROGRAMAS_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\""\
> /etc/sudoers

USER ${USUARIO}:${USUARIO}
WORKDIR ${USUARIO_CASA}

# Crear el perfil de Firefox.
RUN (/usr/bin/timeout --preserve-status 10 /usr/bin/xvfb-run /usr/bin/firefox) ; exit 0

# Configurar el dispositivo de seguridad apropiado e importar los certificados.
RUN	cd .mozilla/firefox && \
	cd $(ls | grep default) && \
	sudo service pcscd start && \
	/usr/bin/modutil -add DNIe -libfile /usr/lib/libpkcs11-dnie.so -dbdir . -secmod secmod.db && \
	sudo service pcscd stop && \
	"${PROGRAMA_DNIE_ABS}" docker-instalar-certificados

CMD ["${PROGRAMA_DNIE_ABS}"]

