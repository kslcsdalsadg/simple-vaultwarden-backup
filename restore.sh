#!/bin/bash

# El script acaba en caso de error

set -e

# Comprobamos que el usuario que ejecuta el script es root

if [ "${EUID}" -ne 0 ]
then 
    echo "Este script lo tiene que ejecutar el usuario 'root'..."
    exit 1
fi

# Comprobamos que se haya recibido un archivo como parámetro y que sea accesible

if [ -z "${1}" ]
then
    echo "No se ha recibido la ruta del archivo de backup a restaurar..."
    exit 1
fi

if [ ! -r "${1}" ]
then
    echo "El archivo de backup a restaurar no existe o no es accesible...";
    exit 1
fi    

# Importamos la configuración

SCRIPT_FOLDER=`dirname ${0}`

. "${SCRIPT_FOLDER}/vaultwarden.conf"

# Comprobamos que se hayan definido los valores de configuración necesarios

if [ -z "${DATA_ROOT}" ] 
then
    echo "Falta alguno de los parámetros de configuración..."
    exit 1
fi

filename=`(basename -- "${1}")`
extension="${filename##*.}"

# Si el archivo está encriptado, entonces también necesitamos datos sobre cómo desencriptar el archivo

if [ "${extension}" = "gpg" ]
then
    if [ -z "${ENCRYPTION_PASSPHRASE}" ] || [ -z "${ENCRYPTION_CIPHER_ALGORITHM}" ]
    then
        echo "Falta alguno de los parámetros de configuración de los backups encriptados..."
        exit 1
    fi
fi

# Comprobamos si el docker de vaultwarden está parado

docker_running=`docker container ls | grep vaultwarden` || true

if [ ! -z "${docker_running}" ]
then
    echo "El container de Vaultwarden debe estar parado para poder restaurar el backup..."
    exit 1
fi

UNENCRYPTED_BACKUP_PATHNAME="${1}"
REMOVE_BACKUP_ON_TERMINATE=""

if [ "${extension}" = "gpg" ]
then
    BACKUP_TIMESTAMP_SUFFIX="$(date '+%Y%m%d-%H%M')"
    UNENCRYPTED_BACKUP_PATHNAME="/tmp/vaultwarden-restore-${BACKUP_TIMESTAMP}"
    REMOVE_BACKUP_ON_TERMINATE="1"
    
    if [ -e "${UNENCRYPTED_BACKUP_PATHNAME}" ]
    then
        echo " Quizás hay otra restauración en marcha, porque el archivo de trabajo ya existe..."
        exit 1
    fi

    # Desencriptamos el archivo a restaurar

    echo "${ENCRYPTION_PASSPHRASE}" | gpg -d --pinentry-mode "loopback" --cipher-algo "${ENCRYPTION_CIPHER_ALGORITHM}" --passphrase-fd 0 "${1}" > "${UNENCRYPTED_BACKUP_PATHNAME}" 
fi
    
# Comprobamos que el archivo a restaurar es un archivo tar

is_not_a_tar=`tar -tf "${UNENCRYPTED_BACKUP_PATHNAME}" 2>&1 > /dev/null` || true
if [ ! -z "${is_not_a_tar}" ]
then
    echo "El archivo no tiene el formato esperado..."
    if [ ! -z "${REMOVE_BACKUP_ON_TERMINATE}" ]
    then
        rm -rf "${UNENCRYPTED_BACKUP_PATHNAME}"
    fi
    exit 1
fi

# Borramos los archivos de transacciones de la BBDD y los directorios que vamos a sobreescribir (para que tengan extrictamente el contenido del backup a restaurar)

for file in db.sqlite3-shm db.sqlite3-wal attachments sends icon_cache
do
    if [ -e "${DATA_ROOT}/${file}" ]
    then    
        rm -rf "${DATA_ROOT}/${file}" 
    fi
done

# Desempaquetamos el archivo a restaurar

tar -xJf "${UNENCRYPTED_BACKUP_PATHNAME}" -C "${DATA_ROOT}"

# Eliminamos el archivo temporal, si es necesario

if [ ! -z "${REMOVE_BACKUP_ON_TERMINATE}" ]
then
    rm -rf "${UNENCRYPTED_BACKUP_PATHNAME}"
fi
