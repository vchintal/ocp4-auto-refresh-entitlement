# Auto-refresh of System Entitlement on RHCOS nodes

### Authors: 
1. Erik Smith (Red Hat)
2. Vijay Chintalapati (Red Hat)


## Background

There is often a need to have **Red Hat Subscription (RHSM)** enabled on the RHCOS nodes of OpenShift to get some workloads to work. For example the GPU workloads that require [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/kubernetes/openshift-on-gpu-install-guide/index.html#openshift-requirements) running.

This repo helps in attaching an RHSM entitlement (key/certificate) to RHCOS nodes via `MachineConfigs` and most importantly ***ensures that if the key/certificate changes for any reason, the nodes are patched with the updated key/certificate***

## Prerequisites for Ansible Control node

1. Ansible version >= `2.10.6`
2. `oc` on the $PATH
3. Python `openshift` package installed. 
   ```
   pip install openshift
   ```
4. Collection `community.kubernetes` installed 
   ``` 
   /usr/bin/ansible-galaxy collection install community.kubernetes
   ```
5. `UUID` of the `Virtual System` to which **Red Hat OpenShift Broker/Master Infrastructure (2 Core)** subscription is or can be attached.

## Deployment 

### Step 1: Customize deployment

From the root of this repo, edit `group_vars/all.yaml` 
* **Required** - Update the value for the key `system_uuid`
* Optional - Update the value for the key `sleep_seconds` that determines how long to wait before performing another iteration (of check/refresh)
* Optional - Update deployment names as needed

### Step 2: Log into OpenShift from Command-Line

Ensuring that variable `$KUBECONFIG` is unset, log into OpenShift cluster as a `cluster-admin` with a command that looks like the one shown below. You can also choose to log-in via a`token` too.

The goal of this is to make sure that the login will update the `~/.kube/confg` file.

```
oc login --server=<server_url>
```

### Step 3: Run the deploy playbook 

```
ansible-playbook deploy.yaml 
```

The above command will :
1. Ask you for your RHSM username and password
2. Create a `Namespace` 
3. Create a `ClusterRole` with write permissions on resources under `machineconfiguration.openshift.io` API Group
4. Create a `ClusterRoleBinding` that maps the `default` service account of the newly created NS to the `ClusterRole` created in #3
5. Extract the key and certificate of the RHSM user for the given system based on its UUID (defined in the `group_vars/all.yaml`)
6. Create a `Secret` using the extracted key, cert and the system's UUID
7. Create an `ImageStream` for the `ose-cli` image
8. Create an `ImageStream` for image to be created using the Dockerfile in folder `container-image`
9. Create a `BuildConfig` that will use OpenShift and build us a new container image using this repo
10. Trigger a new Build using the contents of the folder `container-image`
11. Create a `Deployment` based on the image created that will start a container which will periodically (customizable) check on the entitlement of the system and update it on the worker nodes via a machine config

### Cleanup/Rollback

> Note: The following command **will not** remove the `MachineConfig: 50-machine-entitlements`.

```
ansible-playbook undeploy.yaml 
```

## Additional Documentation
1. https://access.redhat.com/solutions/5807581
