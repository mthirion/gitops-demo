# gitops-demo

## about
This repository is the repository used by an Argocd-backed (deployed on Openshift) gitops process. <br/>
It relies on the Kustomize format.

## structure of the repository
The repositoy contains:
- an "argocd" entry      -> contains yamls to create ArgoCD Application, and yamls to create Openshift Project/Namespace
- a "gitops" entry       -> contains yaml descriptors of applications to be deployed (DC, Services, Routes...) 
- a "templates" entry    -> a template describing the expected (kustomize-compatible) directory struture for one app under the "gitops" entry
- a "pipelines" entry    -> directories containing tekton pipelines, tasks and triggers

## gitops model
The "gitops" directory is the main entry for the applications to be deployed. <br/>
It contains one subdirectory for each "environment" (Openshift project) : dev, int, qa, prod...	<br/>
It corresponds to one ArgoCD Application that will synchronize the entire content. <br/>
With that structure, a quick look at the repository / Argocd Application in the UI tells about which applications have been deployed in which environment and when. <br/>
At the moment the demo only illustrate 2 environments: development and integration <br/>

Example:

     gitops
       |
       |- development
    
            |- application1
        
            |- application2
        
            |- application3
        
       |- integration
    
            |- application1
        
            |- application2
        

## application example
The "pipelines" directory contains the files needed to create the tekton pipelines that will build & deploy the application store in: <br/>
https://github.com/mthirion/quarkus-demo-app-public
 
There are 2 pipelines: <br/>
- The quarkus-builddeploy pipeline ; which is technology-specific (for example java-quarkus) and triggered on 'git push'
- The promote2integration pipeline ; which is technology agnostic and triggered manually

Automated testing is the key element to join the 2 pipelines and complete a DevOps process


The 'buildeploy' pipeline orchestrates the following tasks: <br/>
- clone the git repository (there are also a Trigger, TriggerBindings and EventListener to launch the pipeline automatically on push events)
- build the code using "mvn package"
- build the image using buildah, relying on the Dockerfile present within the application repository
- uses 'jq' utility to manipulate the openshift objects stored in target/kubernetes/openshift.json (and generated automatically by "mvn package" thanks to the Quarkus Openshift plugin)
- pushes the json objects related to the deployment to this gitops repository (dev entry), using the content of the 'templates' directory as a template.

The 'promote2integration' pipeline: <br/>
- promote the image to integration using 'oc tag'
- copy the application structure from 'dev' to 'int' subdirectories within this GitOps repo


## points of improvement
- the first environment should be named different than 'development'
- the promote2integration task promotes images of 'latest' tag.  The pipeline should start from a plain git tag version.


## running the demo

### architecture
![CI/CD pipeline](https://github.com/mthirion/gitops-demo/blob/master/gitops-demo.png)

### prerequisites
- Openshift / CodeReady container (Openshift Local) --version 4.8
- Openshift gitops installed with the operator (thus, argocd running in openshift-gitops namespace)
- A pre-existing "pipelines" namespace
- Pre-existing "development" and "integration" namespace

### preparation
- fork this repo and clone it
- modify the argocd/dev-app.yaml and argocd/int-app.yaml so that it targets your gitops-demo repo
- create the argocd application that will synchronize your gitops-demo repo with your openshift cluster <br/>
  oc apply -f argocd/dev-app.yaml
  oc apply -f argocd/int-app.yaml
  
### creation of the pipelines
create the pipeline tasks: <br/>
- oc apply -f pipelines/quarkus-pipeline/tasks/maven-task-custom.yaml 
- oc apply -f pipelines/quarkus-pipeline/tasks/deploy/deploy-argocd-dev.yaml
- oc apply -f pipelines/quarkus-pipeline/tasks/deploy/deploy-argocd-int.yaml
- oc apply -f pipelines/quarkus-pipeline/tasks/buildah-task-custom.yaml
- oc apply -f pipelines/quarkus-pipeline/tasks/jq/jq-task-custom.yaml 

### tasks configuration
- buildah <br/>
The buildah task can push an image to the same namespace as where the buildah task is running, thus 'pipelines'. <br/>
To push to another namespace ('development') it requires permission that are granted by running: <br/>
oc adm policy add-role-to-user registry-editor system:serviceaccount:pipelines:pipeline 

- jq <br/>
The image used by the jq task (containing the 'jq' utility) can be built with the dockerfile: <br/>
buildah bud -t jq:latest pipelines/quarkus-pipeline/tasks/jq/Dockerfile-jq

The jq tasks executes the script pipelines/quarkus-pipeline/tasks/jq/quarkus-extract-k8s.sh <br/>
This script is injected into the task as a ConfigMap <br/>
oc create cm jq-script --from-file pipelines/quarkus-pipeline/tasks/jq/quarkus-extract-k8s.sh <br/>
OR <br/>
oc apply -f pipelines/quarkus-pipeline/workspaces/jq-cm.yaml

- deploy-argocd-dev and deploy-argocd-int <br/>
To push to github requires a personal access token included as part of the push URI <br/>
This information is propagated to the task using a Secret <br/>
Prepare a file with the URL of the gitops-demo github repository (https://<pat>@github.com/.../demo-gitops.git) <br/>
Then run <br/>
oc create secret generic git-secret --from-file <filename>

### persistent workspaces
The pipeline uses a workspaces for the data (git clone) which should be a PVC: <br/>
oc apply -f pipelines/quarkus-pipeline/workspaces/pipeline-pvc.yaml

The maven task uses an extra PVC to cache downloaded maven artefacts: <br/>
oc apply -f pipelines/quarkus-pipeline/workspaces/maven-pvc.yaml

### Triggers
Create the artefacts:      
oc apply -f pipelines/quarkus-pipeline/trigger/github-push-custom-triggerbinding.yml <br/>
oc apply -f pipelines/quarkus-pipeline/trigger/github-push-triggertemplate.yaml <br/>
oc apply -f pipelines/quarkus-pipeline/trigger/github-push-eventlistener.yaml <br/>
     
Then create the github webhook that points to the Openshift Route created by the EventListener.
     
