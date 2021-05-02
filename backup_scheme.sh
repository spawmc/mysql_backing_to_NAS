#!/usr/bin/env bash

NAME="Respaldo"
DB_NAME="Entidad_sanitaria"
DB_USER=spawn
DB_MY_CNF=/usr/bin/databases/.my.cnf
DATE=$(date +"%d%m%y%H%M")
FILE_NAME=${NAME}${DB_NAME}${DATE}.sql
SMB_IP=172.17.0.4
SMB_FOLDER="sambashare"
SMB_USER="spawnmc"
SMB_PASSWD="joshuan9819"
SHARE_MOUNT_DIR=/mnt/sambashare
MAIL_DEST="spawnmcsqrt@gmail.com"
CNF_FILE=/etc/mysql/my.cnf
CNF_BACKUP_NAME=my.cnf.${DATE}.backup
MAIL_MSG="El backup se ha generado con éxito y se encuentra actualmente en el recurso compartido"

green="\e[0;32m\033[1m"
resetc="\033[0m\e[0m"
red="\e[0;31m\033[1m"
blue="\e[0;34m\033[1m"
yellow="\e[0;33m\033[1m"
purple="\e[0;35m\033[1m"
turquoise="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"

generate_schema_backup(){
    echo "Generando backup del esquema"
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER $DB_NAME --no-data --skip-comments --routines > $FILE_NAME
}

generate_full_backup(){
    echo "Generando backup completo"
    cp $CNF_FILE $CNF_BACKUP_NAME
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER --all-databases > $FILE_NAME
}

copy_cnf_to_shared_resource(){
    if cp $CNF_BACKUP_NAME $SHARE_MOUNT_DIR -f ; then
        rm $CNF_BACKUP_NAME
    fi
}

generate_data_backup(){
    echo "Generando backup de datos"
    mysqldump --defaults-file=$DB_MY_CNF -u $DB_USER --all-databases | gzip > $FILE_NAME.gz
}

make_dir(){
    if [[ -d $SHARE_MOUNT_DIR ]] ; then
        echo "Directorio para recursos compartidos existe."
    else
        sudo mkdir $SHARE_MOUNT_DIR
        echo "Directorio de recursos compartido creado."
    fi
}


mount_shared_resource(){
    if ! df | grep -i $SMB_IP &>/dev/null ; then
        echo "Montando recurso compartido..."
        sudo mount -t cifs -o username=${SMB_USER},password=${SMB_PASSWD} //${SMB_IP}/${SMB_FOLDER} ${SHARE_MOUNT_DIR}
    else
        echo "El recurso compartido ya se encuentra montado"
    fi
}

copy_to_shared_resource(){
    echo "Copiando backup a recurso compartido..."
    if cp $FILE_NAME $SHARE_MOUNT_DIR -f ; then
        rm  $FILE_NAME
    fi
}


send_mail(){
    if ping -c 2 www.google.com &>/dev/null ; then
        echo $MAIL_MSG | mail -s "Backup generado" $MAIL_DEST
        echo "Correo electronico enviado." 
    else
        echo "Sin acceso a internet"
        echo "Correo electronico no enviado"
    fi
}

usage(){
   echo -e "Usage: $0 [options] [--]
    Options:
    -h|help       Display this message
    -s|scheme     Genera backup solo del esquema
    -d|data       Genera backup de datos de toda las bases de datos
    -f|full       Genera un backup comleto de todas las bases de datos y archivos de configuración
    "
}

mysql_status(){
    mysql $>/dev/null
    if $? -eq 1 ; then
        echo -e "\n${red}[-]${resetc} MySql not runnig"
        exit 1;
    else
        echo -e "\n${green}[+]${resetc} MySql runnig"
    fi
}

    while getopts ":h:s:f:d" opt ; do
        case ${opt} in
            h|help)
                usage; exit 0
                ;;
            s|scheme)
                mysql_status
                generate_schema_backup
                make_dir
                mount_shared_resource
                copy_to_shared_resource
                send_mail
                ;;
            f|full)
                mysql_status
                generate_full_backup
                make_dir
                mount_shared_resource
                copy_to_shared_resource
                copy_cnf_to_shared_resource
                send_mail
                ;;
            d|data)
                mysql_status
                generate_data_backup
                make_dir
                mount_shared_resource
                FILE_NAME=${FILE_NAME}.gz
                copy_to_shared_resource
                send_mail
        esac
    done

    shift $(($OPTIND-1))

