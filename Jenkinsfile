/*node 
{
    stage('build-using-scm'){
     echo 'build';
    }
    
    stage('test-using-scm'){
     echo 'test';
    }
    
    stage('deploy-using-scm'){
     echo 'deploy';
    }
}*/
pipeline {
    agent any

    stages {
        stage("Build") {
            steps {
                echo 'Hello World'
                checkout scm
            }
        }
    }

    post {
        always {
            echo 'Hello World'
        }
    }
}

