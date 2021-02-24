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

## Testing the subscription on the RHCOS nodes

Before we perform any tests we want to make sure that the **worker** `MachineConfigPool` is no longer in the *Updating* stage. When the following command is run, the output should be `false`.

```sh 
oc get mcp worker -ojsonpath='{.status.conditions[?(@.type == "Updating")].status}'
```

Now run the following command to ensure the entitlements are correctly applied.

```sh 
oc run -it --rm --image=registry.access.redhat.com/ubi8:latest test-entitlement \
      -- /bin/sh -c "dnf search -y kernel-header --showduplicates"
```

If the test was successful, you should see output similar to the one below.

```text
If you don't see a command prompt, try pressing enter.
Red Hat Enterprise Linux 8 for x86_64 - BaseOS (RPMs)                              20 MB/s |  28 MB     00:01    
Red Hat Enterprise Linux 8 for x86_64 - AppStream (RPMs)                           16 MB/s |  26 MB     00:01    
Red Hat Universal Base Image 8 (RPMs) - BaseOS                                    3.1 MB/s | 775 kB     00:00    
Red Hat Universal Base Image 8 (RPMs) - AppStream                                  29 MB/s | 5.1 MB     00:00    
Red Hat Universal Base Image 8 (RPMs) - CodeReady Builder                         123 kB/s |  13 kB     00:00    
========================================== Name Matched: kernel-header ===========================================
kernel-headers-4.18.0-80.el8.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.4.2.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.1.2.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.el8.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.7.2.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.11.1.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.11.2.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-80.7.1.el8_0.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.0.3.el8_1.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.8.1.el8_1.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.5.1.el8_1.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.0.2.el8_1.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-147.3.1.el8_1.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.el8.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.13.2.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.14.3.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.1.2.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.6.3.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.19.1.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.el8.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-193.28.1.el8_2.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.1.1.el8_3.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.8.1.el8_3.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.10.1.el8_3.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.15.1.el8_3.x86_64 : Header files for the Linux kernel for use by glibc
kernel-headers-4.18.0-240.15.1.el8_3.x86_64 : Header files for the Linux kernel for use by glibc
Session ended, resume using 'oc attach test-entitlement -c test-entitlement -i -t' command when the pod is running
pod "test-entitlement" deleted
```

## Additional Documentation
1. https://access.redhat.com/solutions/5807581
