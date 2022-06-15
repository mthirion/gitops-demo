# gitops-demo

## about
This repository is the repository used by an Argocd-backed (deployed on Openshift) gitops process.
It relies on the Kustomize format.

## structure of the repository
The repositoy contains:
- an "argocd" entry   -> contains ArgoCD Application descriptors, and Openshift Project yamls
- a "gitops" entry    -> contains applications to be deployed (DC, Services... yaml files) 
- a "templates" entry -> a template describing the expected entries for one app under the "gitops" entry (with base/overlays Kustomize substructure)
- a "pipelines" entry -> directories containing tekton pipelines, tasks and triggers

## gitops model
The "gitops" directory is the main entry for the applications to be deployed.
It contains one subdirectory for each "environment" (Openshift project) : dev, int, qa, prod...
It corresponds to one ArgoCD Application that will synchronize the entire content.
With that structure, a quick look at the repository / argocd Application in the UI tells about which applications have been deployed in which environment and when.

Example:
  gitops
    |--> development
        |--> application1
        |--> application2
        |--> application3
    |--> integration
        |--> application1
        |--> application2
