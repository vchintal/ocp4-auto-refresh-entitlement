# Auto-refresh of System Entitlement on RHCOS nodes

## Prerequisites for Control node

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

## Deployment 

### Step 1: Customize deployment

From the root of this repo, edit `group_vars/all.yaml` and 

* Required - Update the value for the key `system_uuid`
* Optional - Update the value for the key `sleep_seconds` that determines how long to wait before performing another iteration (of check/refresh)
* Optional - Update other deployment names

### Step 2: Log into OpenShift from Command-Line

Ensuring that variable `$KUBECONFIG` is unset, log into OpenShift cluster as a `cluster-admin` with a command that looks like the one as shown below. You can choose to log-in via a`token` too.

The goal of this is to make sure that, the login will update the `~/.kube/confg` file.

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
5. Extracts the key and certificate of the RHSM user for the given system based on its UUID (defined in the `group_vars/all.yaml`)
6. Create a `Secret` using the extracted key, cert and the system's UUID
7. Create an `ImageStream` for the `ose-cli` image
8. Create an `ImageStream` for image to be created using the Dockerfile in folder `container-image`
9. Create a `BuildConfig` that will use OpenShift and build us a new container image using this repo
10. Trigger a new Build using the contents of the folder `container-image`
11. Create a `Deployment` based on the image created that will start a container that will repeatedly checks on the entitlement of the system and updates it on the worker nodes via a machine config

### Cleanup/Rollback

> Note: The following command will not remove the `MachineConfig: 50-machine-entitlements`.

```
ansible-playbook undeploy.yaml 
```
