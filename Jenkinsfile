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

    paramenters {
        choice(name:'PerformMavenRelease',choices:'False\nTrue',description:'desc')
        password(name:'CredsToUse',description:'Apassword to build with',defaultValue:'')
    }
    environment {
        BUILD_USR_CHOICE="${params.PerformMavenRelease}"
        BUILD_USR_CREDS="${params.CredsToUse}"
    }

    stages {
        stage("Build") {
            steps {
                echo 'This is a Build step'
                checkout scm
            }
        }
     
        stage('Test') {
            steps{
                echo 'This is a test step'  
            }
        }

        stage('Deploy') {
            steps{
                echo 'This is a deploy step'    
            }
        }
    }
    

    post {
        always {
            echo 'say goodbay'
        }
    }
}

