#!/bin/bash

# El script acaba en caso de error

set -e

# Comprobamos que el usuario que ejecuta el script es root

if [ "${EUID}" -ne 0 ]
then 
    echo "Este script lo tiene que ejecutar el usuario 'root'..."
    exit 1
fi

# Importamos la configuración

SCRIPT_FOLDER=`dirname ${0}`

. "${SCRIPT_FOLDER}/vaultwarden.conf"

# Comprobamos que se hayan definido los valores de configuración necesarios

if [ -z "${DATA_ROOT}" ] || [ -z "${BACKUPS_ROOT}" ]
then
    echo "Falta alguno de los parámetros de configuración..."
    exit 1
fi

# Creamos el directorio de backups si no existe

mkdir -p "${BACKUPS_ROOT}"

# Parámetros de configuración calculados

BACKUP_TIMESTAMP_SUFFIX="$(date '+%Y%m%d-%H%M')"
BACKUP_FILENAME="vaultwarden-${BACKUP_TIMESTAMP_SUFFIX}.tar.xz"
BACKUP_PATHNAME="${BACKUPS_ROOT}/${BACKUP_FILENAME}"
BACKUP_WORKING_FOLDER="/tmp/vaultwarden-backup-${BACKUP_TIMESTAMP}"

# Creamos el directorio de trabajo (en el improbable caso de que ya exista, salimos con un error)

if [ -e "${BACKUP_WORKING_FOLDER}" ]
then
    echo " Quizás hay otro backup en marcha, porque el directorio de trabajo ya existe..."
    exit 1
fi

mkdir -p "${BACKUP_WORKING_FOLDER}"

# Copiamos los ficheros y directorios importantes de Vaultwarden al directorio de trabajo

for file in attachments config.json rsa_key.der rsa_key.pem rsa_key.pub.der rsa_key.pub.pem sends icon_cache
do
    if [ -e "${DATA_ROOT}/${file}" ]
    then
        cp -Rf "${DATA_ROOT}/${file}" "${BACKUP_WORKING_FOLDER}"
    fi
done

# Copiamos también la base de datos de vaultwarden, pero en este caso usamos la herramienta de backup de sqlite3

sqlite3 -cmd ".timeout 30000" "file:${DATA_ROOT}/db.sqlite3?mode=ro" ".backup '${BACKUP_WORKING_FOLDER}/db.sqlite3'"

# Empaquetamos los archivos del directorio temporal en el archivo de backup

tar -cJf "${BACKUP_PATHNAME}" -C "${BACKUP_WORKING_FOLDER}" . 

# Borramos el directorio temporal

rm -rf "${BACKUP_WORKING_FOLDER}"

# Cambiamos el propietario del archivo de backup (opcional)

if [ ! -z "${BACKUPS_OWNER}" ] 
then
    chown "${BACKUPS_OWNER}" "${BACKUP_PATHNAME}"
fi

# Buscamos backups antiguos y los borramos (opcional)

if [ ! -z "${BACKUPS_PURGE_DAYS}" ]
then
    find "${BACKUPS_ROOT}" -mtime "+${BACKUPS_PURGE_DAYS}" -delete
fi

if [ ! -z "${ENCRYPTED_BACKUPS_ROOT}" ]
then

    if [ -z "${ENCRYPTION_PASSPHRASE}" ] || [ -z "${ENCRYPTION_CIPHER_ALGORITHM}" ]
    then
        echo "Falta alguno de los parámetros de configuración de los backups encriptados..."
        exit 1
    fi
        
    ENCRYPTED_BACKUP_PATHNAME="${ENCRYPTED_BACKUPS_ROOT}/${BACKUP_FILENAME}.gpg"
    
    # Creamos el directorio de backups encriptados si no existe

    mkdir -p "${ENCRYPTED_BACKUPS_ROOT}"
    
    # Encriptamos el archivo de backup

    echo "${ENCRYPTION_PASSPHRASE}" | gpg -c --pinentry-mode "loopback" --cipher-algo "${ENCRYPTION_CIPHER_ALGORITHM}" --passphrase-fd 0 --output "${ENCRYPTED_BACKUP_PATHNAME}" "${BACKUP_PATHNAME}"
    
    # Cambiamos el propietario del archivo de backup encriptado (opcional)

    if [ ! -z "${ENCRYPTED_BACKUPS_OWNER}" ] 
    then
        chown "${ENCRYPTED_BACKUPS_OWNER}" "${ENCRYPTED_BACKUP_PATHNAME}"
    fi

    # Buscamos backups encriptados antiguos y los borramos (opcional)

    if [ ! -z "${ENCRYPTED_BACKUPS_PURGE_DAYS}" ]
    then
        find "${ENCRYPTED_BACKUPS_ROOT}" -mtime "+${ENCRYPTED_BACKUPS_PURGE_DAYS}" -delete
    fi
    
    # Comprobamos el archivo de backup encriptado (opcional) 
    
    if [ "${CHECK_ENCRYPTED_FILE}" = "1" ]
    then

        TEMPORARY_UNENCRYPTED_BACKUP_PATHNAME="/tmp/vaultwarden-backup-unencrypted-${BACKUP_TIMESTAMP}"

        echo "${ENCRYPTION_PASSPHRASE}" | gpg -d --pinentry-mode "loopback" --cipher-algo "${ENCRYPTION_CIPHER_ALGORITHM}" --passphrase-fd 0 "${ENCRYPTED_BACKUP_PATHNAME}" > "${TEMPORARY_UNENCRYPTED_BACKUP_PATHNAME}" 

        cant_be_decripted=`diff "${BACKUP_PATHNAME}" "${TEMPORARY_UNENCRYPTED_BACKUP_PATHNAME}"`

        rm "${TEMPORARY_UNENCRYPTED_BACKUP_PATHNAME}"

        if [ ! -z "${cant_be_decripted}" ]
        then
            echo "El archivo de backup no se pudo desencriptar..."
            rm "${ENCRYPTED_BACKUP_PATHNAME}"
            exit 1
        fi
    fi
fi

exit 0
