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

    parameters {
        choice(name:'PerformMavenRelease',choices:'False\nTrue',description:'desc')
        password(name:'CredsToUse',description:'Apassword to build with',defaultValue:'')
    }
    environment {
        BUILD_USR_CHOICE="${params.PerformMavenRelease}"
        BUILD_USR_CREDS="${params.CredsToUse}"
    }

    triggers {
        githubPush()
    }

    stages {
        stage("PreBuild") {
            steps {
                sh 'make check || true'
                echo 'This is a PreBuild step'
                echo "${env.BUILD_USR_CHOICE}"
                echo "branch: ${env.BRANCH_NAME}"
                echo "current SHA: ${env.GIT_COMMIT}"
                checkout scm
            }
        }

       stage('Example'){
            steps{
                echo 'Hello world!'
                script {
                    def username = 'Jenkins'
                    echo 'Hello Mr. ${username}'
                    echo "I said, Hello Mr. ${username}"   
                }
            }
        }


        stage('Build') {
            parallel{
                stage('Build:Module1') { 
                    steps { 
                        echo 'Build Module1 stage ...' 
                    }
                }
                stage('Build:Module2') { 
                    steps { 
                        echo 'Build Module2 stage ...' 
                    }
                }
                stage('Build:Module3') { 
                    steps { 
                        echo 'Build Module3 stage ...' 
                    }
                }
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

