#!/bin/bash

# 1. #OJOCUIDADO! Inicia ProFTPD en 2º plano (no se pueden iniciar varios procesos en 1º plano)
proftpd --nodaemon &

# 2. #OJOCUIDADO! Inicia el servidor SSH en 2º plano (no se pueden iniciar varios procesos en 1º plano)
/usr/sbin/sshd &

# 3. Inicia Apache en 1º plano
apachectl -D FOREGROUND