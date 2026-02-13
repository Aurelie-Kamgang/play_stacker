/* import shared library */
@Library('shared-library') _
pipeline {
    agent none
    environment {
        DOCKERHUB_AUTH = credentials('blondel')
        ID_DOCKER = "${DOCKERHUB_AUTH_USR}"
        PORT_EXPOSED = "80"
        IMAGE_NAME = "alpinebootcamp29"
        IMAGE_TAG = "v1"
        DOCKER_USERNAME = 'blondel'
    }
    stages {
      stage ('Build image'){
          agent any
          steps {
            script {
                sh 'docker build -t ${ID_DOCKER}/${IMAGE_NAME}:${IMAGE_TAG} .'
            }
        }
      }
      stage('Run container based on builded image and test') {
        agent any
        steps {
         script {
           sh '''
              echo "Clean Environment"
              docker rm -f $IMAGE_NAME || echo "container does not exist"
              docker run --name $IMAGE_NAME -d -p ${PORT_EXPOSED}:80 ${ID_DOCKER}/$IMAGE_NAME:$IMAGE_TAG
              sleep 5
              curl http://172.17.0.1:${PORT_EXPOSED} | grep -q "Playbook Stacker"
           '''
         }
        }
      }
      stage('Clean Container'){
          agent any
          steps {
              script {
                  sh '''
                      docker stop $IMAGE_NAME
                      docker rm $IMAGE_NAME
                  '''
              }
          }
      }
      stage('Login and Push Image on docker hub'){
          agent any
          steps {
              script {
                  sh '''
                    docker login -u $DOCKERHUB_AUTH_USR -p $DOCKERHUB_AUTH_PSW
                    docker push ${ID_DOCKER}/$IMAGE_NAME:$IMAGE_TAG
                  '''
              }
          }
      }

      stage('Deploy in staging'){
          agent any
            environment {
                HOSTNAME_DEPLOY_STAGING = "34.229.17.10"
            }
          steps {
            sshagent(['SSH_AUTH_SERVER']) {
                sh '''
                    [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                    ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_STAGING} >> ~/.ssh/known_hosts
                    command1="docker login -u $DOCKERHUB_AUTH_USR -p $DOCKERHUB_AUTH_PSW"
                    command2="docker pull $DOCKERHUB_AUTH_USR/$IMAGE_NAME:$IMAGE_TAG"
                    command3="docker rm -f alpinebootcamp29 || echo 'app does not exist'"
                    command4="docker run -d -p 80:80 --name alpinebootcamp29 $DOCKERHUB_AUTH_USR/$IMAGE_NAME:$IMAGE_TAG"
                    ssh -o StrictHostKeyChecking=no ubuntu@${HOSTNAME_DEPLOY_STAGING} \
                        -o SendEnv=IMAGE_NAME \
                        -o SendEnv=IMAGE_TAG \
                        -o SendEnv=DOCKERHUB_AUTH_USR \
                        -o SendEnv=DOCKERHUB_AUTH_PSW \
                        -C "$command1 && $command2 && $command3 && $command4"
                '''
            }
          }
      }
      stage('Deploy in prod'){
          agent any
            environment {
                HOSTNAME_DEPLOY_PROD = "100.53.133.3"
            }
          steps {
            sshagent(credentials: ['SSH_AUTH_SERVER']) {
                sh '''
                    [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                    ssh-keyscan -t rsa,dsa ${HOSTNAME_DEPLOY_PROD} >> ~/.ssh/known_hosts
                    command1="docker login -u $DOCKERHUB_AUTH_USR -p $DOCKERHUB_AUTH_PSW"
                    command2="docker pull $DOCKERHUB_AUTH_USR/$IMAGE_NAME:$IMAGE_TAG"
                    command3="docker rm -f alpinebootcamp29 || echo 'app does not exist'"
                    command4="docker run -d -p 80:80 --name alpinebootcamp29 $DOCKERHUB_AUTH_USR/$IMAGE_NAME:$IMAGE_TAG"
                    ssh -o StrictHostKeyChecking=no ubuntu@${HOSTNAME_DEPLOY_PROD} \
                        -o SendEnv=IMAGE_NAME \
                        -o SendEnv=IMAGE_TAG \
                        -o SendEnv=DOCKERHUB_AUTH_USR \
                        -o SendEnv=DOCKERHUB_AUTH_PSW \
                        -C "$command1 && $command2 && $command3 && $command4"
                '''
            }
          }
      }        
    }
    post {
        always {
            script {
                slackNotifier currentBuild.result
            }
        }
    }
}
