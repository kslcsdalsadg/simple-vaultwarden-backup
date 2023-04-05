# vaultwarden-backup

Una forma fácil de hacer backups de su bóbeda vaultwarden.

Para empezar, edite el archivo vaultwarden.conf y establezca sus propias preferencias, incluyendo
los parámetros obligatorios:

1) Directorio en el que se ubican los datos de vaultwarden,
2) Directorio destino de los backups (los archivos de backup serán de tipo "tar.xs")

y, opcionalmente:

1) Directorio destino de los backups encriptados (los archivos de backup encriptados serán del tipo "tar.xs.gpg"),
2) La clave de encriptación y el algoritmo a utilizar.

Para hacer un backup ejecute "sh backup.sh" sin parámetros.

Para restaurar un backup anterior ejecute "sh restore.sh /path/backup", donde "/path/backup" puede apuntar a un 
archivo de backup encriptado o no.

