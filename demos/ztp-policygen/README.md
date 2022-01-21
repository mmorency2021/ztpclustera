# ZTP policy gen demo

# Install

First apply the pre-reqs folder where the namespace for each cluster and the proper pull secret and BMC credentials are stored. It is suggested to apply them first because once we create the cluster Argo application it will try to sync and start the provisioning. If it cannot find the pre-reqs the first sync will fail.

```
$ oc apply -k .
namespace/cnfdb1 created
namespace/cnfdb2 created
namespace/eric1 created
secret/assisted-deployment-pull-secret created
secret/cnfdb1-bmh-secret created
secret/assisted-deployment-pull-secret created
secret/cnfdb2-bmh-secret created
secret/assisted-deployment-pull-secret created
secret/eric1-bmh-secret created
```

Then we need to install all the ZTP deployments which are all referenced in the cnf-features-deploy repository (cnf-features-deploy/ztp/gitops-subscriptions/argocd/deployment). 

Before applying modify the `cluster-app.yaml` and `policies-app.yaml` to point to your git repository where all the siteconfigs and policy templates are stored along with the post and pre sync files.

Example of clusters-app:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: clusters-sub
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: clusters
  namespace: openshift-gitops
spec:
  destination:
    server: https://kubernetes.default.svc
    namespace: clusters-sub
  project: default
  source:
    path: demos/ztp-policygen/site-configs
    repoURL: https://gitlab.cee.redhat.com/sysdeseng/5g-ericsson.git
    targetRevision: master
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

Install the deployments:

```
$ oc apply -k .
namespace/clusters-sub created
namespace/policies-sub created
customresourcedefinition.apiextensions.k8s.io/policygentemplates.ran.openshift.io unchanged
customresourcedefinition.apiextensions.k8s.io/siteconfigs.ran.openshift.io unchanged
clusterrole.rbac.authorization.k8s.io/policy-converter unchanged
clusterrole.rbac.authorization.k8s.io/site-converter unchanged
clusterrolebinding.rbac.authorization.k8s.io/site-converter unchanged
clusterrolebinding.rbac.authorization.k8s.io/policy-converter unchanged
clusterrolebinding.rbac.authorization.k8s.io/policy-converter-acm-binding unchanged
clusterrolebinding.rbac.authorization.k8s.io/gitops-cluster unchanged
appproject.argoproj.io/default unchanged
application.argoproj.io/clusters created
application.argoproj.io/policies created
Warning: resource argocds/openshift-gitops is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by oc apply. oc apply should only be used on resources created declaratively by either oc create --save-config or oc apply. The missing annotation will be patched automatically.
argocd.argoproj.io/openshift-gitops configured
```

Sync process will start inmmediately and the post-sync job will be in charge of applying all the manifests stored in our git repository. Once applied, the provisioning will start.

You can verify the process has started by checking the bmh object of each of the SNO clusters you want to deploy:

```
$ oc get bmh -A
NAMESPACE               NAME                                         STATE                    CONSUMER               ONLINE   ERROR
cnfdb1                  snonode.cnfdb1.sno.e2e.bos.redhat.com        provisioning                                    true     
cnfdb2                  snonode.cnfdb2.sno.e2e.bos.redhat.com        provisioning                                    true     
eric1                   snonode.eric1.cloud.lab.eng.bos.redhat.com   provisioning                                    true     
openshift-machine-api   eko5                                         externally provisioned   cnf20-lnbrx-master-0   true     
openshift-machine-api   eko6                                         externally provisioned   cnf20-lnbrx-master-1   true     
openshift-machine-api   eko7                                         externally provisioned   cnf20-lnbrx-master-2   true     
```

# Cleaning

Here it is detailed the process to remove some parts of the ZTP flow.

## Remove everything

First we need to remove the remote clusters. Note that this can be done from RHACM user interface as well by just detaching and destroy cluster.

```
$ oc get managedclusters
NAME            HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE   AGE
cnfdb1          true                                  True     True        3d1h
cnfdb2          true                                  True     True        2d
eric1           true                                  True     True        3d1h
local-cluster   true                                  True     True        7d
```

```
$ oc delete managedclusters cnfdb1 cnfdb2 eric1
managedcluster.cluster.open-cluster-management.io "cnfdb1" deleted
managedcluster.cluster.open-cluster-management.io "cnfdb2" deleted
managedcluster.cluster.open-cluster-management.io "eric1" deleted
```

Then, you can delete the namespace associated to that cluster. The namespace name is the same as the managedCluster name.

> Note: You will have to wait until the namespace is eventually removed.

```
$ oc delete ns cnfdb1 cnfdb2 eric1
namespace "cnfdb1" deleted
namespace "cnfdb2" deleted
namespace "eric1" deleted
```

Next, we can start removing the "gitops" objects (ArgoCD). We will need to remove the Argo application, but this is not going to remove all the associated objects. So, we will have to continue removing the rest of the components of the ZTP workflow.

```
$ oc get applications.argoproj.io -A
NAMESPACE          NAME       SYNC STATUS   HEALTH STATUS
openshift-gitops   clusters   Synced        Healthy
openshift-gitops   policies   Synced        Healthy
```
```
$ oc delete applications.argoproj.io clusters policies -n openshift-gitops
application.argoproj.io "clusters" deleted
application.argoproj.io "policies" deleted
```

At this point confirm accessing the ArgoCD UI that there is no application shown there. Note that you can remove the applications from the UI as well.

Next, we will have to remove the Custom Resource Definitions created to deploy and configure the policies. Basically we can just remove the namespaces associated to them.

```
$ oc get siteconfig -A
NAMESPACE      NAME           AGE
telco-5g-lab   telco-5g-lab   6d20h
westford-lab   westford-lab   6d21h
```
```
$ oc delete siteconfig telco-5g-lab -n telco-5g-lab
siteconfig.ran.openshift.io "telco-5g-lab" deleted
$ oc delete siteconfig westford-lab -n westford-lab
siteconfig.ran.openshift.io "westford-lab" deleted
```
```
$ oc get policygentemplate -A
NAMESPACE               NAME           AGE
cnfdb1-policies         cnfdb1         6d21h
cnfdb2-policies         cnfdb2         2d19h
common                  common         6d21h
eric1-policies          eric1          6d21h
group-du-sno            group-du-sno   6d21h
westford-lab-policies   westford-lab   6d21h
```

```
$ oc delete ns cnfdb1-policies  cnfdb2-policies common eric1-policies group-du-sno westford-lab-policies
namespace "cnfdb1-policies" deleted
namespace "cnfdb2-policies" deleted
namespace "common" deleted
namespace "eric1-policies" deleted
namespace "group-du-sno" deleted
namespace "westford-lab-policies" deleted
```

Finally remove the namespaces where the jobs associated with the pre-sync and post-sync tasks in ArgoCD.

```
$ oc get jobs -A | grep post
clusters-sub               siteconfig-post                                                   1/1           19s        2d
policies-sub               policygentemplates-post                                           1/1           16s        20h
```
```
$ oc delete ns clusters-sub policies-sub
namespace "clusters-sub" deleted
namespace "policies-sub" deleted
```

# Redeploy a whole site or cluster

First we need to remove the remote cluster or all the clusters inside a site

```
$ oc get managedclusters
NAME            HUB ACCEPTED   MANAGED CLUSTER URLS   JOINED   AVAILABLE   AGE
cnfdb1          true                                  True     True        3d1h
cnfdb2          true                                  True     True        2d
eric1           true                                  True     True        3d1h
local-cluster   true                                  True     True        7d
```

```
$ oc delete managedcluster _cluster_name_
```

Then, you can delete the namespace associated to that cluster. The namespace name is the same as the managedCluster name.

> Note: You will have to wait until the namespace is eventually removed.

```
$ oc delete ns _managedCluster_name_
```

Once they are removed from ACM, they are ready to be provisioned and configured again. First, apply the pre-requisites which basically contains the creation of the namespace for the cluster and their pull secret and BMC credentials.

```
$ oc apply -k _path_to_pre_reqs_ (/ocp-ztp/)
```

Next we need to push the site's siteConfig and PolicyGen files to our git repository. If they are already pushed and you did not change anything, e.g, you just want to reinstall it exactly the same configuration you will need to create a change so the post-sync job see a change and will apply all the required objects.

For instance by just adding a label or modify a label inside the proper siteconfig (see label called redeploy: 1). The commit and push changes so Argo will sync them.

```
  clusters:
  - clusterName: "eric1"
    clusterType: "sno"
    clusterProfile: "du"
    clusterLabels:
      group-du-sno: ""
      common: true
      sites : "westford-lab"
      redeploy: "1"
```
