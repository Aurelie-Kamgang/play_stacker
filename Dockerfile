# Utiliser une image de base légère comme Alpine ou un serveur web de base
FROM nginx:1.27-alpine

# Définir le répertoire de travail dans le conteneur
WORKDIR /usr/share/nginx/html

# Copier le fichier index.html dans le conteneur
COPY index.html /usr/share/nginx/html/index.html

COPY assets ./assets

COPY dist ./dist

# Exposer le port 80 pour le serveur web Nginx
EXPOSE 80
