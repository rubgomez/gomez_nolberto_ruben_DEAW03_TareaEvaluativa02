# Utilizamos una imagen oficial de Ubuntu
FROM ubuntu:26.04

# Damos información sobre la imagen que estamos creando
LABEL \
    #***version="1.0" \
    version="2.0" \
    description="Ubuntu + Apache2 + virtual host" \
    maintainer="usuarioBIRT <usuarioBIRT@birt.eus>"

#RESUMEN DE LO SOLICITADO:
#***1: tunombre1:sitioprimero: FTP seguro (mod) + certificado(A+N) + no SHELL
#***2: tunombre2:sitiosegundo: SSH (mod) + SCP (mod) + SFTP (mod) + no FTP
#***3: Anonymous:git@github.com:deaw-birt/UD3-ftp_anonimo.git FTP anónimo (Git+clavePRIV)

# Actualizamos la lista de paquetes e instalamos nano y apache2
ENV DEBIAN_FRONTEND=noninteractive

#***RUN apt-get update && \
#***    apt-get install -y nano apache2 && \
#***    rm -rf /var/lib/apt/lists/*

    #******
	RUN apt-get update && apt-get install -y \
        #*** Instalamos Apache
        apache2 \
        #*** Instalamos Nano
        nano \
		#***1: Instalamos PROftpD
		proftpd \
		#***1: Biblioteca para gestionar certificados y claves seguras
		openssl \
		#***1: módulo de criptografía y TLS
		proftpd-mod-crypto \
		#***3: Instala herramientas de GitHub
		git \
		#***2: instala el servidor SSH y crea la carpeta sshd ( La carpeta la necesita el servidor para arrancar en un contenedor)
		openssh-server && mkdir -p /run/sshd\
		#limpiar la caché de los paquetes de APT después de instalar programas
		&& rm -rf /var/lib/apt/lists/*
    #******

# Creamos directorios para los sitios web y configuraciones
RUN mkdir -p /var/www/html/sitio1 /var/www/html/sitio2

# Copiamos archivos al contenedor
COPY index1.html /var/www/html/sitio1/index.html
COPY index2.html /var/www/html/sitio2/index.html
COPY sitio1.conf /etc/apache2/sites-available/
COPY sitio2.conf /etc/apache2/sites-available/
COPY sitio1.key /etc/ssl/private/
COPY sitio1.cer /etc/ssl/certs/

#***1: crea usuario rubgomez1
RUN groupadd ftpgroup && \
useradd -s /sbin/nologin -d /var/www/html/sitio1 -g ftpgroup rubgomez1 && \
	#-m: crea la carpeta de usuario en el home si no existe
	#-s /sbin/nologin: shell sin login (solo FTP; requiere RequireValidShell off en proftpd.conf)
    #-d /srv/deaw: fija la ruta del home a esa ruta
	echo "rubgomez1:clave12345678" | chpasswd && \
	#asignamos contraseña
	echo "fichero de rubgomez1" > /var/www/html/sitio1/rubgomez1.txt && \
	#crea un archivo dentro de su home
	chown -R rubgomez1:ftpgroup /var/www/html/sitio1/
    #asigna la "propiedad" de la carpeta recursivamente al usuario y grupo

#***2: crea usuario rubgomez2
RUN useradd -s /bin/bash -d /var/www/html/sitio2  rubgomez2 && \
	echo "rubgomez2:clave12345678" | chpasswd && \
	echo "fichero de rubgomez2" > /var/www/html/sitio2/rubgomez2.txt && \
	chown -R rubgomez2:rubgomez2 /var/www/html/sitio2/

#***Creamos otro usuario extra para poder probar que sólo hace login
RUN useradd -m -s /bin/bash deaw && \
	echo "deaw:clave12345678" | chpasswd && \
    echo "fichero de deaw" > /home/deaw/deaw.txt 

# Habilitamos los sitios y el módulo SSL
RUN a2ensite sitio1.conf && \
    a2ensite sitio2.conf && \
    a2enmod ssl

#***1:Generar clave PRIV y el certificado autofirmado en las rutas Ubuntu
RUN openssl req -new -x509 -nodes -keyout /etc/ssl/private/servidor.key -out /etc/ssl/certs/servidor.pem -days 365 -newkey rsa:2048 \
-subj "/C=ES/ST=Euskadi/L=Vitoria/O=BirtLH/CN=Ruben Gomez" && \
		#req -new -x509: Crea directamente el certificado autofirmado
		#-nodes: Significa "no password"
		#-keyout servidor.key: crea y guarda la clave PRIV en ese archivo
		#-out servidor.pem : indica el archivo de salida donde se guardará el certificado	
		#-days 365: validez
		#-subj: datos del certificado 
		#"/C=ES/ST=Euskadi/L=Vitoria/O=BirtLH/CN=www.rubgomez.eus"
			#C= = País (Country)
			#ST= = Provincia / Estado (State)
			#L= = Localidad / Ciudad (Locality)
			#O= = Organización / Empresa (Organization)
			#CN= = Nombre común / Dominio web (Common Name)
    chmod 600 /etc/ssl/private/servidor.key && \
	#chmod 600: root puede leer y escribir
	chmod 644 /etc/ssl/certs/servidor.pem
	#chmod 644: sólo root puede modificarlo, pero cualquiera puede leerlo

#capa contenido: Copia archivos y directorios desde anfitrión
    #***1,2y3: copia archivos de prueba
	COPY Configuraciones/proftpd.conf /etc/proftpd/proftpd.conf
	COPY Configuraciones/tls.conf /etc/proftpd/tls.conf
    #***1y2: copia archivos de prueba
	COPY Recursos/sitio1 /var/www/html/sitio1/ 
    COPY Recursos/sitio2 /var/www/html/sitio2/ 

	#OJOCUIDADO!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    #***3: copia de la clavePRIV SSH
    COPY Configuraciones/ud3_ftp_key /root/.ssh/id_rsa
            #*** /root/.ssh/id_rsa: ruta estandar donde se guardan las clavePRIV SSH
            #*** .ssh: carpeta oculta
            #*** id_rsa : nombre estándar para clavePRIV en RSA
	
	#OJOCUIDADO! esto hay que hacerlo todo en una misma instrucción para que no quede registro! 		
    #chmod 600: root puede leer y escribir
    RUN chmod 600 /root/.ssh/id_rsa && \
	#Añadir GitHub a los known_hosts para evitar bloqueos interactivos
	mkdir -p /root/.ssh && ssh-keyscan github.com >> /root/.ssh/known_hosts && \
	#Git se niega a clonar si la carpeta de destino no está vacía (OJOCUIDADO! rm -rf /srv/ftp/* && da ERROR)
	rm -rf /srv/ftp/ && \
	#Creamos de nuevo la carpeta
	mkdir /srv/ftp && \
	#Clonamos el directorio en la ruta de acceso
	git clone git@github.com:deaw-birt/UD3-ftp_anonimo.git /srv/ftp && \
	##OJOCUIDADO! Borramos la clavePRIV para que no se quede en la imagen
	rm -f /root/.ssh/id_rsa

	#***copia el script de inicio
	COPY Configuraciones/inicio.sh /inicio.sh
	#***damos permisos de ejecución al script
	RUN chmod +x /inicio.sh

# Exponemos los puertos
EXPOSE 80
EXPOSE 443
#***1: FTP
EXPOSE 21 50000-50030
#***2:SSH
EXPOSE 22

# Comando por defecto al iniciar el contenedor
#***CMD ["apachectl", "-D", "FOREGROUND"]
#***script para arrancar ProFTPD + Apache + SSH
CMD ["/inicio.sh"]