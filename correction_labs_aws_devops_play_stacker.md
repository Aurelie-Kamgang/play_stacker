# Correction des labs — AWS DevOps 2h

Repository utilisé : `https://github.com/Aurelie-Kamgang/play_stacker.git`

Objectif : partir du repository existant **Play Stacker**, construire une image Docker, la pousser dans **Amazon ECR**, puis automatiser le build avec **AWS CodeBuild** et **AWS CodePipeline**.

---

## Lab 0 — Récupérer le repository

### Objectif
Cloner le repository existant et vérifier les fichiers utiles.

### Commandes

```bash
git clone https://github.com/Aurelie-Kamgang/play_stacker.git
cd play_stacker

ls -la
```

### Vérification attendue

Vous devez voir au minimum :

```text
Dockerfile
docker-compose.yml
package.json
index.html
assets/
dist/
src/
```

### Explication

On ne part pas d’un projet vide. Le repository contient déjà une application web, un Dockerfile et un fichier docker-compose. Le travail DevOps consiste maintenant à rendre ce projet buildable et automatisable sur AWS.

---

## Lab 1 — Lire rapidement le projet

### Objectif
Identifier les fichiers importants avant d’automatiser.

### Commandes utiles

```bash
cat package.json
cat Dockerfile
cat docker-compose.yml
```

### Points à comprendre

```text
index.html       -> page principale du jeu
assets/          -> ressources statiques du jeu
dist/            -> fichier JavaScript généré utilisé par index.html
Dockerfile       -> recette de création de l’image Docker
docker-compose.yml -> test Docker local
buildspec.yml    -> fichier à ajouter pour AWS CodeBuild
```

---

## Lab 2 — Tester avec Docker localement

### Objectif
Valider que l’application peut être servie par Nginx avant d’utiliser AWS.

### Build Docker

```bash
docker build -t play-stacker:local .
```

### Lancer le conteneur

```bash
docker run -d --name play-stacker-demo -p 8080:80 play-stacker:local
```

### Tester dans le navigateur

Ouvrir :

```text
http://localhost:8080
```

### Vérifier le conteneur

```bash
docker ps
```

### Nettoyer

```bash
docker stop play-stacker-demo
docker rm play-stacker-demo
```

---

## Lab 3 — Améliorer le Dockerfile

### Objectif
Remplacer le Dockerfile existant par une version plus propre.

Le Dockerfile actuel copie tout le repository. Pour un projet statique servi par Nginx, on peut copier uniquement les éléments nécessaires.

### Dockerfile recommandé

Créez ou remplacez le fichier `Dockerfile` :

```Dockerfile
FROM nginx:1.27-alpine

WORKDIR /usr/share/nginx/html

COPY index.html ./
COPY assets ./assets
COPY dist ./dist

EXPOSE 80
```

### Ajouter un fichier `.dockerignore`

Créez un fichier `.dockerignore` :

```text
.git
.gitignore
node_modules
npm-debug.log
README.md
README.zh-CN.md
LICENSE
Jenkinsfile
```

### Rebuilder l’image

```bash
docker build -t play-stacker:clean .
```

### Lancer le test

```bash
docker run -d --name play-stacker-clean -p 8080:80 play-stacker:clean
```

Tester ensuite :

```text
http://localhost:8080
```

### Nettoyer

```bash
docker stop play-stacker-clean
docker rm play-stacker-clean
```

---

## Lab 4 — Créer le repository Amazon ECR

### Objectif
Créer un registre Docker privé dans AWS.

### Variables

Adaptez la région si nécessaire.

```bash
export AWS_REGION=eu-west-3
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REPO=play-stacker
export REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO
```

### Créer le repository ECR

```bash
aws ecr create-repository \
  --repository-name $ECR_REPO \
  --image-scanning-configuration scanOnPush=true \
  --region $AWS_REGION
```

### Vérifier l’URI

```bash
echo $REPOSITORY_URI
```

Format attendu :

```text
123456789012.dkr.ecr.eu-west-3.amazonaws.com/play-stacker
```

---

## Lab 5 — Tester le push Docker vers ECR manuellement

### Objectif
Valider ECR avant CodeBuild.

### Connexion Docker à ECR

```bash
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### Taguer l’image locale

```bash
docker tag play-stacker:clean $REPOSITORY_URI:manual
```

### Pousser l’image

```bash
docker push $REPOSITORY_URI:manual
```

### Vérifier dans ECR

```bash
aws ecr list-images \
  --repository-name $ECR_REPO \
  --region $AWS_REGION
```

---

## Lab 6 — Ajouter le fichier buildspec.yml

### Objectif
Donner à AWS CodeBuild les instructions pour construire et pousser l’image.

Créez le fichier `buildspec.yml` à la racine du repository.

### Version simple avec tag `latest`

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Connexion à Amazon ECR..."
      - aws --version
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - AWS_REGION=${AWS_DEFAULT_REGION}
      - ECR_REPO=play-stacker
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      - IMAGE_TAG=latest

  build:
    commands:
      - echo "Construction de l'image Docker..."
      - docker build -t $ECR_REPO:$IMAGE_TAG .

  post_build:
    commands:
      - echo "Tag de l'image..."
      - docker tag $ECR_REPO:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG
      - echo "Push de l'image vers Amazon ECR..."
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo "Build terminé avec succès. Image poussée vers $REPOSITORY_URI:$IMAGE_TAG"
```

### Committer le fichier

```bash
git status
git add Dockerfile .dockerignore buildspec.yml
git commit -m "Add AWS CodeBuild configuration"
git push origin main
```

---

## Lab 7 — Version bonus du buildspec avec tag commit

### Objectif
Éviter d’utiliser uniquement le tag `latest`.

Remplacez le contenu de `buildspec.yml` par cette version si vous voulez tracer chaque build avec le hash du commit.

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Connexion à Amazon ECR..."
      - aws --version
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - AWS_REGION=${AWS_DEFAULT_REGION}
      - ECR_REPO=play-stacker
      - REPOSITORY_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
      - echo "Image tag = $IMAGE_TAG"

  build:
    commands:
      - echo "Construction de l'image Docker..."
      - docker build -t $ECR_REPO:$IMAGE_TAG .

  post_build:
    commands:
      - echo "Tag de l'image..."
      - docker tag $ECR_REPO:$IMAGE_TAG $REPOSITORY_URI:$IMAGE_TAG
      - docker tag $ECR_REPO:$IMAGE_TAG $REPOSITORY_URI:latest
      - echo "Push vers ECR..."
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - docker push $REPOSITORY_URI:latest
      - echo "Image poussée : $REPOSITORY_URI:$IMAGE_TAG"
```

---

## Lab 8 — Créer le projet AWS CodeBuild

### Objectif
Créer un build AWS capable de lire le repository et d’exécuter `buildspec.yml`.

### Configuration conseillée dans la console AWS

```text
Service : AWS CodeBuild
Project name : play-stacker-build
Source provider : GitHub
Repository : Aurelie-Kamgang/play_stacker
Branch : main
Environment image : Managed image
Operating system : Ubuntu
Runtime : Standard
Image : aws/codebuild/standard:7.0 ou version disponible équivalente
Privileged mode : activé
Buildspec : Use a buildspec file
Buildspec name : buildspec.yml
```

### Variables d’environnement CodeBuild

Ajoutez si vous souhaitez les utiliser explicitement :

```text
ECR_REPO=play-stacker
IMAGE_TAG=latest
```

Dans la version proposée du `buildspec.yml`, la région est lue avec `AWS_DEFAULT_REGION`, disponible automatiquement dans CodeBuild.

### Point très important

Le mode privilégié doit être activé, sinon Docker ne pourra pas construire l’image.

---

## Lab 9 — Permissions IAM pour CodeBuild

### Objectif
Donner à CodeBuild les droits nécessaires pour écrire dans ECR et CloudWatch Logs.

### Option simple pour un lab

Pour un atelier court, vous pouvez attacher au rôle CodeBuild :

```text
AmazonEC2ContainerRegistryPowerUser
CloudWatchLogsFullAccess
```

### Option plus propre : policy personnalisée

Adaptez la région, l’account ID et le nom du repository.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:BatchGetImage"
      ],
      "Resource": "arn:aws:ecr:eu-west-3:123456789012:repository/play-stacker"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## Lab 10 — Lancer un build manuel

### Objectif
Tester CodeBuild avant CodePipeline.

### Étapes

```text
1. Ouvrir AWS CodeBuild
2. Ouvrir le projet play-stacker-build
3. Cliquer sur Start build
4. Ouvrir les logs
5. Vérifier les phases : pre_build, build, post_build
6. Vérifier l’image dans ECR
```

### Vérification AWS CLI

```bash
aws ecr list-images \
  --repository-name play-stacker \
  --region eu-west-3
```

---

## Lab 11 — Créer AWS CodePipeline

### Objectif
Déclencher CodeBuild automatiquement après un changement GitHub.

### Configuration conseillée

```text
Pipeline name : play-stacker-pipeline
Source provider : GitHub via CodeStar Connection
Repository : Aurelie-Kamgang/play_stacker
Branch : main
Trigger : push sur la branche main
Build provider : AWS CodeBuild
Project : play-stacker-build
Deploy stage : ne pas ajouter pour cette séance
```

### Résultat attendu

Le pipeline doit contenir deux étapes :

```text
Source -> Build
```

---

## Lab 12 — Tester le pipeline avec un commit

### Objectif
Vérifier que le pipeline se déclenche après un push GitHub.

### Exemple de modification simple

Dans `index.html`, changez le titre de la page ou ajoutez un petit texte visible.

Exemple :

```html
<title>Playbook Stacker - AWS Pipeline</title>
```

### Commit et push

```bash
git status
git add index.html
git commit -m "Update page title for pipeline test"
git push origin main
```

### Vérifications

```text
1. CodePipeline passe par Source
2. CodePipeline lance Build
3. CodeBuild réussit
4. ECR contient une image récente
```

---

## Lab 13 — Diagnostic des erreurs fréquentes

### Erreur : Docker daemon inaccessible

Message possible :

```text
Cannot connect to the Docker daemon
```

Correction :

```text
Activer Privileged mode dans CodeBuild.
```

---

### Erreur : ECR login impossible

Message possible :

```text
no basic auth credentials
```

Corrections :

```text
Vérifier la région AWS.
Vérifier l’account ID.
Vérifier que la commande aws ecr get-login-password fonctionne.
Vérifier les permissions IAM du rôle CodeBuild.
```

---

### Erreur : Repository ECR introuvable

Message possible :

```text
repository does not exist
```

Corrections :

```text
Vérifier que le repository ECR s’appelle bien play-stacker.
Vérifier qu’il est dans la même région que CodeBuild.
Vérifier la valeur de REPOSITORY_URI.
```

---

### Erreur : YAML incorrect

Message possible :

```text
YAML_FILE_ERROR
```

Corrections :

```text
Vérifier l’indentation du buildspec.yml.
Utiliser des espaces, pas des tabulations.
Vérifier que le fichier est bien à la racine du repository.
```

---

## Lab 14 — Challenge final

### Mission
Réaliser toute la chaîne sans suivre ligne par ligne le formateur.

### Travail à faire

```text
1. Modifier index.html
2. Faire un commit
3. Pousser vers GitHub
4. Observer CodePipeline
5. Lire les logs CodeBuild
6. Vérifier l’image dans ECR
7. Expliquer le chemin complet à voix haute
```

### Réponse attendue

```text
Le développeur pousse un commit dans GitHub.
CodePipeline détecte le changement.
CodePipeline déclenche CodeBuild.
CodeBuild lit buildspec.yml.
CodeBuild construit l’image Docker à partir du Dockerfile.
CodeBuild se connecte à Amazon ECR.
CodeBuild pousse l’image Docker dans ECR.
```

---

## Lab 15 — Nettoyage AWS

### Objectif
Éviter de garder des ressources inutiles.

### Ressources à nettoyer

```text
CodePipeline : play-stacker-pipeline
CodeBuild : play-stacker-build
ECR : images ou repository play-stacker
CloudWatch Logs : logs du build si nécessaire
```

### Commandes CLI possibles

Supprimer le pipeline :

```bash
aws codepipeline delete-pipeline \
  --name play-stacker-pipeline \
  --region eu-west-3
```

Supprimer le projet CodeBuild :

```bash
aws codebuild delete-project \
  --name play-stacker-build \
  --region eu-west-3
```

Supprimer le repository ECR avec ses images :

```bash
aws ecr delete-repository \
  --repository-name play-stacker \
  --force \
  --region eu-west-3
```

---

## Résumé final

À la fin du cours, le participant doit savoir expliquer cette chaîne :

```text
GitHub -> CodePipeline -> CodeBuild -> Docker build -> Amazon ECR
```

Il doit aussi savoir diagnostiquer les erreurs simples :

```text
Problème Docker -> vérifier le mode privilégié CodeBuild
Problème ECR -> vérifier région, URI et permissions IAM
Problème buildspec -> vérifier indentation et emplacement du fichier
Problème pipeline -> vérifier connexion GitHub et branche surveillée
```
