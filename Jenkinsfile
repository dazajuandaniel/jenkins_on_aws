// Jenkinsfile
String credentialsId = 'aws_credentials'

try {
  stage('checkout') {
    node {
      cleanWs()
      checkout scm
    }
  }

  stage('Download Terraform') {
    node {
      sh "curl -o terraform.zip https://releases.hashicorp.com/terraform/0.12.26/terraform_0.12.26_linux_amd64.zip"
    }
  }

  stage('Install Unzip') {
    node {
      sh "sudo apt install unzip"
    }
  }

  stage('Unzip Terraform Python') {
    node {
      sh "unzip terraform.zip"
    }
  }
  

  stage('Unpacks Terraform') {
    node {
      sh "sudo mv terraform /usr/bin"
    }
  }

  stage('Cleanup Terraform') {
    node {
      sh "rm -rf terraform.zip"
    }
  }

  stage('Echo Folder Files') {
    node {
      sh "ls -a"
    }
  }

  stage('Echo Location') {
    node {
      sh "pwd"
    }
  }

  // Run terraform init
  stage('init') {
    node {
      withCredentials([[
        $class: 'AmazonWebServicesCredentialsBinding',
        credentialsId: credentialsId,
        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
      ]]) {
        sh 'terraform init'
      }
    }
  }

  // Run terraform plan
  stage('plan') {
    node {
      withCredentials([[
        $class: 'AmazonWebServicesCredentialsBinding',
        credentialsId: credentialsId,
        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
      ]]) {
        sh 'terraform plan'
      }
    }
  }

  if (env.BRANCH_NAME == 'master') {

    // Run terraform apply
    stage('apply') {
      node {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: credentialsId,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh 'terraform apply -auto-approve'
        }
      }
    }

    // Run terraform show
    stage('show') {
      node {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: credentialsId,
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh 'terraform show'
        }
      }
    }
  }
  currentBuild.result = 'SUCCESS'
}
catch (org.jenkinsci.plugins.workflow.steps.FlowInterruptedException flowError) {
  currentBuild.result = 'ABORTED'
}
catch (err) {
  currentBuild.result = 'FAILURE'
  throw err
}
finally {
  if (currentBuild.result == 'SUCCESS') {
    currentBuild.result = 'SUCCESS'
  }
}
