#! /bin/bash

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

# Tareas pendientes en "dnie.sh"
# XXX: Ejecutar por defecto el comando 'navegador'. Hacer que ese comando ejecute el comando 'construir' si la imagen del contenedor no existiese.
# XXX: Mantener la configuración del usuario en el volumen a parte, manteniendo el directorio de descargas conectado a un directorio del anfitrión.
# XXX: Asegurarse de que la comprobación del volumen de datos es efectiva.
# XXX: Añadir soporte para proxy.
# XXX: Ver porqué la primera vez falla la página de bienvenida.
# XXX: Debo buscar una forma de usar la opción "--device" en lugar de "--privileged" y "--volume" al arrancar el contenedor. El problema es localizar los dispositivos de lectores de tarjetas.
# XXX: Solucionar problema con "timbres" generados en la consola en segundo plano.
# XXX: Añadir comprobación explícita de todos los programas externos necesarios.
# XXX: 	* unar, cabextract, 
# Tareas pendientes en "Dockerfile"
# XXX: Encontrar una forma de arrancar el navegador durante la configuración de la imagen sin "timeout", y a poder ser sin "xvfb-run". El parámetro "--headless" debería servir para esto, pero no consigo que funcione.
# XXX: Poner enlaces en los favoritos del navegador:
# XXX: XXX: https://sede.administracion.gob.es/carpeta
# XXX: XXX: https://www.agenciatributaria.gob.es
# XXX: XXX: https://sede-tu.seg-social.gob.es
# XXX: Hacer que Firefox sea el navegador por defecto.

# Comprobar si se está usando el intérprete adecuado.
if [ "${BASH}x" = "x" ] ; then
	echo "Este programa debe ejecutarse con el intérprete 'BASH'." 1>&2
	exit 1
fi

DNIE_PROGRAMA_VERSION=0.0.1

# 1. FUNCIONES
##############
function comprobarPermisosDocker {
	if ! id -nG "$USER" | grep -qw "docker" ; then
		if [ "$EUID" -ne 0 ] ; then
			echo "Este comando debe ejecutarlo un usuario con permisos de ejecución de comandos 'Docker'."
			exit 1
		fi
	fi
}

# Determina si existe el volumen de datos y si no, lo crea.
function comprobarVolumenDatos {
	mkdir -p ${DNIE_DIR}
}

function descargarBinarios {
	eval "declare -A aa="${1#*=}

	URL="${aa[url]}"
	if [ "${URL}x" = "x" ] ; then
		# Esta entrada no tiene URL. Saltar.
		return 1
	fi

	mkdir -p "${DESCARGAS_DIR}"
	pushd "${DESCARGAS_DIR}"

	FICHERO_DESCARGA_NOMBRE="${URL##*/}"

	if [ -f "${FICHERO_DESCARGA_NOMBRE}" ] ; then
		echo "El fichero '${FICHERO_DESCARGA_NOMBRE}' ya existe. No será descargado." 1>&2
		return 0
	fi

	${WGET} "${URL}"

	FICHERO_DESCARGA_EXTENSION="${FICHERO_DESCARGA_NOMBRE##*.}"
	FICHERO_DESCARGA_EXTENSION="${FICHERO_DESCARGA_EXTENSION,,}"
	case ${FICHERO_DESCARGA_EXTENSION} in
		"crt" | "deb")
			# No es necesario llevar a cabo ninguna acción para estas extensiones.
			RES=0
		;;
		"cab")
			/usr/bin/cabextract "${FICHERO_DESCARGA_NOMBRE}"
			RES=$?
		;;
		"rar")
			/usr/bin/unar "${FICHERO_DESCARGA_NOMBRE}"
			RES=$?
		;;
		*)
			echo "Extensión de fichero no reconocida '${FICHERO_DESCARGA_EXTENSION}'" 1>&2
			exit 1
		;;
	esac

	popd
	unset URL

	if [ ! ${RES} ] ; then
		echo "Error al procesar el archivo '${FICHERO_DESCARGA_NOMBRE}'." 1>&2
		exit 1
	fi
}

function imprimirAyuda {
	read -r -d '' AYUDA_VAR <<- _AYUDA
		AYUDA
		================================================================================
		* Todos los documentos que guardes en el directorio "casa" dentro del navegador
		  estarán disponibles para otras aplicaciones en el directorio "${DNIE_DIR}".
	_AYUDA
	printf "\n${AYUDA_VAR}\n\n"
}

function imprimirNotaGarantiaYCondiciones {
	read -r -d '' TEXTO_VAR <<- _BLOQUE_TEXTO
		NOTA SOBRE GARANTÍA Y CONDICIONES
		================================================================================
		dnie.sh v${DNIE_PROGRAMA_VERSION} Copyright (C) 2017  Guillermo López Alejos
		This program comes with ABSOLUTELY NO WARRANTY; for details type
		"dnie.sh garantía".
		This is free software, and you are welcome to redistribute it
		under certain conditions; type "dnie.sh condiciones" for details.
	_BLOQUE_TEXTO
	printf "\n${TEXTO_VAR}\n\n"
}

function imprimirGrantia {
	read -r -d '' TEXTO_VAR <<- _BLOQUE_TEXTO
		GARANTÍA
		================================================================================
		THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
		APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
		HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
		OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
		THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
		PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
		IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
		ALL NECESSARY SERVICING, REPAIR OR CORRECTION.
	_BLOQUE_TEXTO
	printf "\n${TEXTO_VAR}\n\n"
}

function imprimirCondiciones {
	read -r -d '' TEXTO_VAR <<- _BLOQUE_TEXTO
		CONDICIONES
		================================================================================
		Ver https://www.gnu.org/licenses/gpl-3.0.txt
	_BLOQUE_TEXTO
	printf "\n${TEXTO_VAR}\n\n"
}

function imprimirUsoYSalir {
	echo "Uso:" 1>&2
	echo "	$0 <construir | comprobar | navegador | cmd | docker-comprobar | docker-instalar-certificados | docker-navegador | garantía | condiciones>" 1>&2
	echo "" 1>&2
	echo "Antes de poder ejecutar el navegador hay que construir la imagen de Docker con el comando 'construir'. Una vez construida, puede ejecutarse el navegador con el comando 'navegador'" 1>&2
	echo "" 1>&2
	exit 1
} 

function instalarCertificados {
	eval "declare -A aa="${1#*=}

	CONFIANZA_CERTIFICADO="${aa[confianza_certificado]}"
	if [ "${CONFIANZA_CERTIFICADO}x" = "x" ] ; then
		# Esta entrada no tiene definido un modelo de confianza para el certificado. Saltar.
		return 1
	fi


	CERTIFICADO_NOMBRE="${aa[certificado]}"
	if [ "${CERTIFICADO_NOMBRE}x" = "x" ] ; then
		# Esta entrada no tiene certificado explícito, intentar obtener de la URL..
		URL="${aa[url]}"
		if [ "${URL}x" = "x" ] ; then
			# Esta entrada no tiene URL. Saltar.
			return 1
		fi
		CERTIFICADO_NOMBRE="${URL##*/}"
	fi

	if [ -f "${CERTIFICADO_NOMBRE}" ] ; then
		CERTIFICADO_ABS="${CERTIFICADO_NOMBRE}"

		if [ ! -f "${CERTIFICADO_ABS}" ] ; then
			echo "No existe el fichero de certificado '${CERTIFICADO_ABS}'." 1>2&
			exit 1
		fi
	else
		CERTIFICADO_ABS="${DOCKER_DESCARGAS_DIR}/${CERTIFICADO_NOMBRE}"
	fi

	echo "Instalando certificado '${CERTIFICADO_ABS}'..."
	pwd

	# Se asume que el directorio de trabajo actual es el perfil de Firefox a configurar.
	/usr/bin/certutil -A -d . -t "${CONFIANZA_CERTIFICADO}" -n "${CERTIFICADO_NOMBRE}" -i "${CERTIFICADO_ABS}"
	RES=$?

	if [ ! ${RES} ] ; then
		echo "Error al procesar el certificado '${CERTIFICADO_ABS}'." 1>&2
		exit 1
	fi
}


# Esta función recorre la lista de mapas referenciada por la variable "INFO_BINARIOS" invocando una función pasada por parámetro con cada mapa encontrado.
# 	$1: Función a invocar por cada mapa encontrado. A esta función se le pasará el mapa encontrado.
function procesarBinarios {
	FUNCION=$1
	for ((i = 0; i < ${#INFO_BINARIOS[@]}; i++))
	do
		IFS='|' read -ra campos <<< "${INFO_BINARIOS[$i]}"

		declare -A aa

		for ((j = 0; j < ${#campos[@]}; j++))
		do
			IFS='º' read -ra nombreValor <<< "${campos[$j]}"
			aa[${nombreValor[0]}]=${nombreValor[1]}
		done

		${FUNCION} "$(declare -p aa)"
		unset aa
	done
}

# 2. VALIDACIÓN DE PARÁMETROS DE ENTRADA
########################################
COMANDO=$1 
if [ -z "$COMANDO" ] ; then
	imprimirUsoYSalir
fi

# 3. VARIABLES DE CONFIGURACIÓN
###############################
# 3.1. Usuario
DNIE_DIR=~/dnie
# Directorio en el que se encuentran los paquetes externos a instalar. Si no se encuentran, se descargarán sobre la marcha.
PAQUETES_FUENTE_DIR=${DNIE_DIR}/dnie_paquetes_fuente
DESCARGAS_DIR=${PAQUETES_FUENTE_DIR}/descargas
PAQUETE_DESCARGAS_NOMBRE=descargas.tar.gz
PAQUETE_DESCARGAS_ABS=${PAQUETES_FUENTE_DIR}/${PAQUETE_DESCARGAS_NOMBRE}
# Nombre del usuario a utilizar. Tiene que coincidir con un nombre de usuario válido en el sistema o no cuadrarán los permisos.
USUARIO=$(whoami)

# 3.2. DEPENDENCIAS (PROGRAMAS)
CABEXTRACT=/usr/bin/cabextract
DIRNAME=/usr/bin/dirname
REALPATH=/usr/bin/realpath
TAR=/bin/tar
UNAR=/usr/bin/unar
WGET=/usr/bin/wget

# 3.3. DEPENDENCIAS (LIBRERÍAS)
PROGRAMA_DNIE_FICHERO=dnie.sh
PROGRAMA_DNIE_DIR="$(${DIRNAME} $(${REALPATH} $0))"
PROGRAMA_DNIE_ABS="${PROGRAMA_DNIE_DIR}/${PROGRAMA_DNIE_FICHERO}"

# 3.4. BINARIOS PARA DESCARGAR
# PKCS11
PKCS11_ARQ=amd64
PKCS11_V=1.4.0
PKCS11_FICHERO="Debian_ 8 Jessie_libpkcs11-dnie_${PKCS11_V}_${PKCS11_ARQ}.deb"
PKCS11_ENLACE="https://www.dnielectronico.es/descargas/distribuciones_linux/Debian-64bits/${PKCS11_FICHERO}"

# FORMATO
# La variable "INFO_BINARIOS" hace referencia a una lista de mapas. Como en BASH no es posible hacer este anidamiento, debe codificarse como una lista de cadenas de texto. Cada cadena de texto se divide con el carácter "|" en campos. Cada campo es una pareja clave-valor. La clave se separa del valor con el carácter "º". Descripción de los campos:
# * url: Dirección de la que descargar el binario.
# * certificado: Nombre del fichero una vez descomprimido.
# * confianza_certificado: argumentos de confianza a pasar a la herramienta "certutil" (ver opción "-t" en https://mdn.mozilla.org/en-US/docs/Mozilla/Projects/NSS/Reference/NSS_tools_:_certutil)
INFO_BINARIOS=()
INFO_BINARIOS+=("urlº${PKCS11_ENLACE}")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACRAIZ-DNIE2.cab|certificadoºAC RAIZ DNIE 2.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACRAIZ-SHA1.CAB|certificadoºACRAIZ-SHA1.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACRAIZ-SHA2.CAB|certificadoºACRAIZ-SHA2.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACDNIE001-SHA2.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACDNIE002-SHA2.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/ZIP/ACDNIE003-SHA2.crt|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("urlºhttps://www.dnielectronico.es/descargas/certificados/Ocsp Responder AV DNIE-FNMT_SHA2.rar|certificadoºAV DNIE FNMT 2017.cer|confianza_certificadoºTC,TC,TC")
INFO_BINARIOS+=("certificadoº/usr/share/libpkcs11-dnie/ac_raiz_dnie.crt|confianza_certificadoºTC,TC,TC")

# 3.5. DOCKER
# Ver https://hub.docker.com/r/library/debian/tags/ para más versiones de Debian.
DEBIAN_V=9.1

DOCKER_IMAGEN_ETIQUETA="debian/dnie:${DNIE_PROGRAMA_VERSION}"
DOCKER_CONTENEDOR_NOMBRE="dnie"
DOCKER_PROGRAMAS_DIR=/opt/dnie
DOCKER_PROGRAMA_DNIE_ABS=${DOCKER_PROGRAMAS_DIR}/${PROGRAMA_DNIE_FICHERO}
DOCKER_FIREFOX_DIR=/usr/lib/firefox-esr
DOCKER_FIREFOX_EJEC=/usr/bin/firefox
DOCKER_FIREFOX_TRAZAS_DIR=/var/log/dnie
DOCKER_USUARIO_CASA=/home/${USUARIO}
DOCKER_COMPARTIDO_DIR=${DOCKER_USUARIO_CASA}/Descargas
DOCKER_PARAMS="-ti"
DOCKER_PARAMS="$DOCKER_PARAMS --rm"
DOCKER_PARAMS="$DOCKER_PARAMS --env DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix"
DOCKER_PARAMS="$DOCKER_PARAMS --user ${USUARIO}:${USUARIO}"
DOCKER_PARAMS="$DOCKER_PARAMS --net=host"
DOCKER_PARAMS="$DOCKER_PARAMS --volume ${DNIE_DIR}:${DOCKER_COMPARTIDO_DIR}"
DOCKER_PARAMS="$DOCKER_PARAMS --privileged=true --volume /dev:/dev"
DOCKER_PARAMS="$DOCKER_PARAMS --name=${DOCKER_CONTENEDOR_NOMBRE}"

###############################################################################
## 4. COMANDO
###############################################################################
case $COMANDO in
"construir")
	imprimirNotaGarantiaYCondiciones
	comprobarPermisosDocker

	# 2. PREPARAR ENTORNO
	#####################
	DOCKERFILE_ABS="${PROGRAMA_DNIE_DIR}/Dockerfile"
	if [ ! -f "${DOCKERFILE_ABS}" ] ; then
		echo "El fichero 'Dockerfile' no está en el mismo directorio que '$0' y debe estarlo." 1>&2
		exit 1
	fi

	# Directorio de paquetes fuente.
	if [ ! -d "${PAQUETES_FUENTE_DIR}" ] ; then
		mkdir -p "${PAQUETES_FUENTE_DIR}"
		RES=$?
		if [ ! ${RES} ] ; then
			echo "Error al crear el directorio de paquetes fuente '${PAQUETES_FUENTE_DIR}'." 1>&2
			exit 1
		fi
	fi

	# UID del usuario
	USUARIO_UID=$(id -u ${USUARIO})
	RES=$?
	if [ ! ${RES} ] ; then
		echo "Error al obtener el UID del usuario '${USUARIO}'." 1>&2
		exit 1
	fi

	# GID del usuario
	USUARIO_GID=$(id -g ${USUARIO})
	RES=$?
	if [ ! ${RES} ] ; then
		echo "Error al obtener el GID del usuario '${USUARIO}'." 1>&2
		exit 1
	fi

	# 3. DESCARGAR RECURSOS Y PREPARAR FUENTES
	##########################################
	procesarBinarios descargarBinarios
	${TAR} fcz "${PAQUETE_DESCARGAS_ABS}" -C "${DESCARGAS_DIR}" .

	pushd ${PAQUETES_FUENTE_DIR}

	cp ${PROGRAMA_DNIE_ABS} .
	cp ${DOCKERFILE_ABS} .

	docker build \
		--build-arg DEBIAN_V=${DEBIAN_V} \
		--build-arg USUARIO=${USUARIO} \
		--build-arg USUARIO_UID=${USUARIO_UID} \
		--build-arg USUARIO_GID=${USUARIO_GID} \
		--build-arg DOCKER_PROGRAMAS_DIR="${DOCKER_PROGRAMAS_DIR}" \
		--build-arg DOCKER_FIREFOX_TRAZAS_DIR="${DOCKER_FIREFOX_TRAZAS_DIR}" \
		--build-arg PROGRAMA_DNIE_FICHERO="${PROGRAMA_DNIE_FICHERO}" \
		--build-arg PAQUETE_DESCARGAS_NOMBRE="${PAQUETE_DESCARGAS_NOMBRE}" \
		--build-arg PKCS11_FICHERO="${PKCS11_FICHERO}" \
		--tag ${DOCKER_IMAGEN_ETIQUETA} ${PAQUETES_FUENTE_DIR}

	RES=$?
	if [ ! ${RES} ] ; then
		echo "Error al construir la imagen de Docker." 1>&2
		exit 1
	fi
	popd
	;;
"comprobar")
	imprimirNotaGarantiaYCondiciones
	comprobarPermisosDocker

	echo "Asegúrese de que el lector de tarjetas está insertado. Pulse una tecla una vez esté listo..."
	read -s
	echo "Analizando lector de tarjetas. Introduzca el DNI electrónico y compruebe que es reconocido correctamente. Pulse 'Ctrl. + C' para terminar."
	docker run ${DOCKER_PARAMS} ${DOCKER_IMAGEN_ETIQUETA} ${DOCKER_PROGRAMA_DNIE_ABS} docker-comprobar
	;;
"navegador")
	imprimirNotaGarantiaYCondiciones
	imprimirAyuda

	comprobarPermisosDocker
	comprobarVolumenDatos

	xhost + local:docker
	docker run ${DOCKER_PARAMS} ${DOCKER_IMAGEN_ETIQUETA} ${DOCKER_PROGRAMA_DNIE_ABS} docker-navegador
	xhost - local:docker
	;;
"cmd")
	imprimirNotaGarantiaYCondiciones
	imprimirAyuda

	comprobarPermisosDocker
	comprobarVolumenDatos

	xhost + local:docker
	docker run ${DOCKER_PARAMS} ${DOCKER_IMAGEN_ETIQUETA} /bin/bash
	xhost - local:docker
	;;
"docker-comprobar")
	sudo service pcscd start
	pcsc_scan
	sudo service pcscd stop
	;;
"docker-instalar-certificados")
	procesarBinarios instalarCertificados

	;;
"docker-navegador")
	sudo service pcscd start
	${DOCKER_FIREFOX_EJEC} > ${DOCKER_FIREFOX_TRAZAS_DIR}/$(date +%Y%m%d_%H%M%S)_firefox.out 1>&2
	sudo service pcscd stop
	;;
"garantía")
	imprimirGrantia
	;;
"condiciones")
	imprimirCondiciones
	;;
*)
	imprimirUsoYSalir
	;;
esac

echo "Comando terminado."
exit 0

