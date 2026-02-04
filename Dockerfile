# Utiliser une image de base légère comme Alpine ou un serveur web de base
FROM nginx:latest

# Définir le répertoire de travail dans le conteneur
WORKDIR /usr/share/nginx/html

# Copier le fichier index.html dans le conteneur
COPY index.html /usr/share/nginx/html/index.html

# Copier les autres fichiers nécessaires (si vous en avez)
COPY . /usr/share/nginx/html/

# Exposer le port 80 pour le serveur web Nginx
EXPOSE 8082