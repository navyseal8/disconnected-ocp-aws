# Disconnected OCP on aws

Target OpenShift: 
- 4.19.17

Operators: 
- [x] openshift-gitops-operator
- [x] ansible-automation-platform-operator
- [x] gitlab-runner-operator
- [x] gitlab-operator-kubernetes
- [x] hcp-terraform-operator
- [x] splunk-operator
- [x] vault-secrets-operator

## Provision AWS resources

1. Login to AWS console, select region
2. Nagivate to CloudFormation
3. Provision template using [cloudformation.yaml](cloudformation.yaml)

## AWS Architecture

This is based off the work from https://naps-product-sa.github.io/ocp4-disconnected-workshop/modules/index.html

- The lowside bastion lives in the public subnet, and able to download release images.
- The highside bastion lives in the private subnet and serve as the mirror-registry.
- The disconnected OpenShift will be provisioned in the private subnet, simulating no internal access.
- The squid proxy allows limited traffic to aws private endpoint (for provisiong purpose).

![AWS][aws.png]

## Prepare bastion host

1. Download oc-mirror v2 
```
$ curl -L -o oc-mirror.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/oc-mirror.rhel9.tar.gz
$ tar -xzf oc-mirror.tar.gz
$ rm -f oc-mirror.tar.gz
$ chmod +x oc-mirror
$ sudo cp -v oc-mirror /bin
```
2. Download mirror-registry
```
$ wget -c https://mirror.openshift.com/pub/cgw/mirror-registry/latest/mirror-registry-amd64.tar.gz
```

3. Download openshift-install

```
Make sure to download 4.19.17
$ wget -c https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.19.17/openshift-install-linux-4.19.17.tar.gz
$ tar -xzf openshift-install-linux-4.19.17.tar.gz openshift-install
$ rm -f openshift-install-linux-4.19.17.tar.gz
```

4. Download oc
```
$ curl -L -o oc.tar.gz https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz
$ tar -xzf oc.tar.gz oc
$ rm -f oc.tar.gz
$ sudo cp -v oc /bin
```

## Mirror registry and operators to local disk (On Bastion Host)

1. Create [imageset-config.yaml](imageset-config.yaml) to your specific OpenShift version.
2. Select the operators that you need by checking against the catalog index image

```
$ oc-mirror list operators --catalog registry.redhat.io/redhat/redhat-operator-index:v4.19
NAME                                            DISPLAY NAME  DEFAULT CHANNEL
3scale-operator                                               threescale-2.16
advanced-cluster-management                                   release-2.14
amq-broker-rhel8                                              7.12.x
amq-broker-rhel9                                              7.13.x
amq-online                                                    stable
...<snip>...

$ oc-mirror list operators --catalog registry.redhat.io/redhat/certified-operator-index:v4.19
NAME                                                 DISPLAY NAME  DEFAULT CHANNEL
abinitio-runtime-operator                                          release-4.3
accuknox-operator-certified                                        stable
aci-containers-operator                                            stable
aic-operator                                                       alpha
airlock-microgateway                                               4.8
aiu-operator                                                       stable-v2.3
...<snip>...

$ oc-mirror list operators --catalog registry.redhat.io/redhat/community-operator-index:v4.19
NAME                                       DISPLAY NAME  DEFAULT CHANNEL
3scale-community-operator                                threescale-2.13
ack-acm-controller                                       alpha
ack-acmpca-controller                                    alpha
ack-apigateway-controller                                alpha
ack-apigatewayv2-controller                              alpha
ack-applicationautoscaling-controller                    alpha
...<snip>...
```

3. Setup your credentials (pull-secrets)

```
$ mkdir -v $HOME/.docker
$ cp -v /path/to/pull-secret.json $HOME/.docker/config.json
$ podman login registry.redhat.io
Authenticating with existing credentials for registry.redhat.io
Existing credentials are valid. Already logged in to registry.redhat.io
```

4. Mirror the OpenShift version release packages
```
*** Do these in tmux session ***

$ tmux new -s mirror-operation
$ cd /mnt/low-side-data
$ oc-mirror --config imageset-config.yaml file:///mnt/low-side-data --v2
2025/11/13 06:00:13  [INFO]   : 👋 Hello, welcome to oc-mirror
2025/11/13 06:00:13  [INFO]   : ⚙️  setting up the environment for you...
2025/11/13 06:00:13  [INFO]   : ⚙️  environment version: 4.20.0-202510221121.p2.gb51b46d.assembly.stream.el9-b51b46d
2025/11/13 06:00:13  [INFO]   : 🔀 workflow mode: mirrorToDisk
2025/11/13 06:00:13  [INFO]   : 🕵   going to discover the necessary images...
2025/11/13 06:00:13  [INFO]   : 🔍 collecting release images...
 ✓   () Collecting release quay.io/openshift-release-dev/ocp-release:4.19.17-x86_64
2025/11/13 06:00:21  [INFO]   : 🔍 collecting operator images...
 ✓   (1m19s) Collecting catalog registry.redhat.io/redhat/redhat-operator-index:v4.19
 ✓   (46s) Collecting catalog registry.redhat.io/redhat/certified-operator-index:v4.19
2025/11/13 06:02:26  [WARN]   : [OperatorImageCollector] registry.redhat.io/openshift4/ose-kube-rbac-proxy-rhel9:v4.18@sha256:784c4667a867abdbec6d31a4bbde52676a0f37f8e448eaae37568a46fcdeace7 has both tag and digest : using digest to pull, but tag only for mirroring
2025/11/13 06:02:26  [WARN]   : [OperatorImageCollector] registry.redhat.io/rhel9/postgresql-15:1@sha256:5e225c1646251d2509b3a6e45fad23abfb11dd5c45d3224b59178f90deb38a70 has both tag and digest : using digest to pull, but tag only for mirroring
..........
..........
 ✓   (4s)  platform-operator-bundle@sha256:8a0c1713c6cc87f96c21a03c566652369f5671e77c881e7fcf4835b0318ed916 ➡️  cache
 ✓   (2s)  gitops-operator-bundle@sha256:a27b8dd047e10fbbd6fc49176036c9b5178a1d2841e26719bfde23239ede157d ➡️  cache
 ✓   (4s)  gitlab-operator-bundle@sha256:d7508e6d8edd9bf720728ea185f58b04b9e2eb398bf832e9c4aea3080b614643 ➡️  cache
 ✓   (4s)  certified-operator-index:v4.19 ➡️  cache
 ✓   (4s)  redhat-operator-index:v4.19 ➡️  cache
 ✓   (1m16s)  ubi@sha256:20f695d2a91352d4eaa25107535126727b5945bff38ed36a3e59590f495046f0 ➡️  cache
249 / 249 (33m7s) [==================================================================================================================] 100 %
 ✓   (8m38s)  lightspeed-chatbot-rhel9@sha256:7f10633a97769d9d5a7e96633bf1566e8836213e9ce35b14d31b258f5a858017 ➡️  cache
2025/11/13 06:37:20  [INFO]   : === Results ===
2025/11/13 06:37:20  [INFO]   :  ✓  191 / 191 release images mirrored successfully
2025/11/13 06:37:20  [INFO]   :  ✓  57 / 57 operator images mirrored successfully
2025/11/13 06:37:20  [INFO]   :  ✓  1 / 1 additional images mirrored successfully
2025/11/13 06:37:20  [INFO]   : 📦 Preparing the tarball archive...
2025/11/13 06:52:45  [INFO]   : mirror time     : 48m43.803369031s
2025/11/13 06:52:45  [INFO]   : 👋 Goodbye, thank you for using oc-mirror
```

## Transfer the installer content

```
$ rsync -avP /mnt/low-side-data/ highside:/mnt/high-side-data/

# 65G of data to copy - 10 mins
```
## Prepare registry (At the Highside Host)

1. Setup mirror-registry on Highside host
```
$ ssh highside
$ cd /mnt/high-side-data
$ tar -xzvf mirror-registry-amd64.tar.gz
image-archive.tar
execution-environment.tar
mirror-registry
sqlite3.tar

$ sudo mv -v /mnt/high-side-data/oc /bin/
$ sudo mv -v /mnt/high-side-data/oc-mirror /bin/
$ sudo mv -v /mnt/high-side-data/openshift-install /bin/
```
2. Create mirror-registry
```
$ ./mirror-registry install --initPassword <your-password>

TASK [mirror_appliance : Create init user] *************************************************************************************************
included: /runner/project/roles/mirror_appliance/tasks/create-init-user.yaml for lab-user@ip-10-0-51-146.ap-southeast-1.compute.internal

TASK [mirror_appliance : Creating init user at endpoint https://ip-10-10-10-10.ap-southeast-1.compute.internal:8443/api/v1/user/initialize] ***
ok: [lab-user@ip-10-10-10-11.ap-southeast-1.compute.internal]

TASK [mirror_appliance : Enable lingering for systemd user processes] **********************************************************************
changed: [lab-user@ip-10-10-10-10.ap-southeast-1.compute.internal]

PLAY RECAP *********************************************************************************************************************************
lab-user@ip-10-0-51-146.ap-southeast-1.compute.internal : ok=49   changed=30   unreachable=0    failed=0    skipped=15   rescued=0    ignored=0

INFO[2025-11-13 07:07:21] Quay installed successfully, config data is stored in ~/quay-install
INFO[2025-11-13 07:07:21] Quay is available at https://ip-10-10-10-10.ap-southeast-1.compute.internal:8443 with credentials (init, your-password)

```
3. Update the certificate chain
```
$ sudo cp -v $HOME/quay-install/quay-rootCA/rootCA.pem /etc/pki/ca-trust/source/anchors/
$ sudo update-ca-trust
```

4. Login to your new mirror-registry
```
$ podman login -u init -p your-password $(hostname):8443
Login Succeeded!

# podman login command creates an authentication file / pull secret at $XDG_RUNTIME_DIR/containers/auth.json
```

## diskToMirror
- Estimate time = 15 mins to extract, 30 mins to upload to mirrored registry

```
$ cd /mnt/high-side-data
$ cp mirror_00001.tar /mnt/high-side-data/disk
$ oc-mirror -c ./imageset-config.yaml --from file:///mnt/high-side-data/disk docker://$(hostname):8443 --v2
2025/11/13 07:23:02  [INFO]   : 👋 Hello, welcome to oc-mirror                                                                             2025/11/13 07:23:02  [INFO]   : ⚙️  setting up the environment for you...                                                                   2025/11/13 07:23:02  [INFO]   : ⚙️  environment version: 4.20.0-202510221121.p2.gb51b46d.assembly.stream.el9-b51b46d                        2025/11/13 07:23:02  [INFO]   : 🔀 workflow mode: diskToMirror                                                                             2025/11/13 07:23:02  [INFO]   : Verified we can authenticate against registry "ip-10-0-51-146.ap-southeast-1.compute.internal:8443"        2025/11/13 07:23:02  [INFO]   : 📦 Extracting mirror archive(s)...
/mnt/high-side-data/disk/mirror_000001.tar (56.9 GiB / 56.9 GiB) [==================================================================] 15m24s
2025/11/13 07:38:27  [INFO]   : 🕵   going to discover the necessary images...                                                              2025/11/13 07:38:27  [INFO]   : 🔍 collecting release images...                                                                            2025/11/13 07:38:27  [INFO]   : 🔍 collecting operator images...
 ✓   () Collecting catalog registry.redhat.io/redhat/certified-operator-index:v4.19
 ✓   () Collecting catalog registry.redhat.io/redhat/redhat-operator-index:v4.19
2025/11/13 07:38:27  [INFO]   : 🔍 collecting additional images...
2025/11/13 07:38:27  [WARN]   : registry.redhat.io/rhel9/support-tools unable to parse image correctly : tag and digest are empty : SKIPPING
2025/11/13 07:38:27  [INFO]   : 🔍 collecting helm images...
2025/11/13 07:38:27  [INFO]   : 🚀 Start copying the images...
2025/11/13 07:38:27  [INFO]   : 📌 images to copy 249
 ✓ (28s)  ocp-v4.0-art-dev@sha256:03dab2b186d374f92a01f77591e324ea4dcca3f3fa3c693c3d716ee1edd9eba0 ➡️  ip-10-0-51-146.ap-southeast-…
 ✓ (31s)  ocp-v4.0-art-dev@sha256:40e8776a6efe4fa2b684551615afba5ebfddc387868a932d8464792f315f855e ➡️  ip-10-0-51-146.ap-southeast-…
 ✓ (31s)  ocp-v4.0-art-dev@sha256:02222ed048523ec13f1e8dd7cb58594b923330fa66eac556d89962f754993427 ➡️  ip-10-0-51-146.ap-southeast-…
.....
.....
 ✓ (9s)  vault-secrets-operator-bundle@sha256:e284d0839795f763ca53402c2b050fa9ffedebccd0f3832fe7259368c3ad32f2 ➡️  ip-10-0-51-146.a…
 ✓   (1m9s)  redhat-operator-index:v4.19 ➡️  ip-10-0-51-146.ap-southeast-1.compute.internal:8443/redhat/
 ✓   (1m9s)  certified-operator-index:v4.19 ➡️  ip-10-0-51-146.ap-southeast-1.compute.internal:8443/redhat/
249 / 249 (31m47s) [=================================================================================================================] 100 %
 ✓ (6m20s)  lightspeed-chatbot-rhel9@sha256:7f10633a97769d9d5a7e96633bf1566e8836213e9ce35b14d31b258f5a858017 ➡️  ip-10-0-51-146.ap-…
2025/11/13 08:10:15  [INFO]   : === Results ===
2025/11/13 08:10:15  [INFO]   :  ✓  191 / 191 release images mirrored successfully
2025/11/13 08:10:15  [INFO]   :  ✓  57 / 57 operator images mirrored successfully
2025/11/13 08:10:15  [INFO]   :  ✓  1 / 1 additional images mirrored successfully
2025/11/13 08:10:15  [INFO]   : 📄 Generating IDMS file...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/idms-oc-mirror.yaml file created
2025/11/13 08:10:15  [INFO]   : 📄 Generating ITMS file...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/itms-oc-mirror.yaml file created
2025/11/13 08:10:15  [INFO]   : 📄 Generating CatalogSource file...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/cs-redhat-operator-index-v4-19.yaml file created
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/cs-certified-operator-index-v4-19.yaml file created
2025/11/13 08:10:15  [INFO]   : 📄 Generating ClusterCatalog file...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/cc-redhat-operator-index-v4-19.yaml file created
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/cc-certified-operator-index-v4-19.yaml file created
2025/11/13 08:10:15  [INFO]   : 📄 Generating Signature Configmap...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/signature-configmap.json file created
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/signature-configmap.yaml file created
2025/11/13 08:10:15  [INFO]   : 📄 Generating UpdateService file...
2025/11/13 08:10:15  [INFO]   : /mnt/high-side-data/disk/working-dir/cluster-resources/updateService.yaml file created
2025/11/13 08:10:15  [INFO]   : mirror time     : 47m13.040009773s
2025/11/13 08:10:15  [INFO]   : 👋 Goodbye, thank you for using oc-mirror

```
## Install disconnected OpenShift

1. Customise the OpenShift cluster using [install-config.yaml](install-config.yaml)
- Estimate ~45-60 mins installation time

```
# Update SSH-key, pullSecret, imageContentSource, trustBundles etc

$ ssh-keygen -C "OpenShift Debug" -N "" -f /mnt/high-side-data/id_rsa
$ echo "sshKey: $(cat /mnt/high-side-data/id_rsa.pub)" | tee -a /mnt/high-side-data/install-config.yaml
$ echo "pullSecret: '$(jq -c . $XDG_RUNTIME_DIR/containers/auth.json)'" | tee -a /mnt/high-side-data/install-config.yaml

$ cat << EOF >> /mnt/high-side-data/install-config.yaml
imageContentSources:
$(grep -A2 "mirrors:" --no-group-separator /mnt/high-side-data/disk/working-dir/cluster-resources/idms-oc-mirror.yaml)
EOF

$ cat << EOF >> /mnt/high-side-data/install-config.yaml
additionalTrustBundle: |
$(sed 's/^/  /' /home/lab-user/quay-install/quay-rootCA/rootCA.pem)
EOF
```

2. Start the installation
```
# Backup your install-config.yaml as it gets erase 

$ cp install-config.yaml /mnt/highside/installer/
$ openshift-install create cluster --dir /mnt/high-side-data/installer
WARNING platform.aws.subnets is deprecated. Converted to platform.aws.vpc.subnets
WARNING imageContentSources is deprecated, please use ImageDigestSources
INFO Credentials loaded from the AWS config using "SharedConfigCredentials: /home/lab-user/.aws/config" provider
INFO Successfully populated MCS CA cert information: root-ca 2035-11-11T09:04:00Z 2025-11-13T09:04:00Z
INFO Successfully populated MCS TLS cert information: root-ca 2035-11-11T09:04:00Z 2025-11-13T09:04:00Z
INFO Consuming Install Config from target directory
INFO Adding clusters...
INFO Creating infrastructure resources...
INFO Reconciling IAM roles for control-plane and compute nodes
INFO Creating IAM role for master
INFO Creating IAM role for worker
...
...
...
INFO Control-plane machines are ready
INFO Cluster API resources have been created. Waiting for cluster to become ready...
INFO Waiting up to 20m0s (until 9:27AM UTC) for the Kubernetes API at https://api.xxxx.sandboxXXXX.opentlc.com:6443...
INFO API v1.32.9 up
INFO Waiting up to 45m0s (until 9:59AM UTC) for bootstrapping to complete...
INFO Waiting for the bootstrap etcd member to be removed...
INFO Bootstrap etcd member has been removed
INFO Destroying the bootstrap resources...
INFO Waiting up to 5m0s for bootstrap machine deletion openshift-cluster-api-guests/xxxx-45j9s-bootstrap...
INFO Shutting down local Cluster API controllers...
INFO Stopped controller: Cluster API
INFO Stopped controller: aws infrastructure provider
INFO Shutting down local Cluster API control plane...
INFO Local Cluster API system has completed operations
INFO Finished destroying bootstrap resources
INFO Waiting up to 40m0s (until 10:20AM UTC) for the cluster at https://api.xxxx.sandboxXXXX.opentlc.com:6443 to initialize...
INFO Waiting up to 30m0s (until 10:27AM UTC) to ensure each cluster operator has finished progressing...
INFO All cluster operators have completed progressing
INFO Checking to see if there is a route at openshift-console/console...
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run
INFO     export KUBECONFIG=/mnt/high-side-data/installer/auth/kubeconfig
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.xxxxx.sandboxXXXX.opentlc.com
INFO Login to the console with user: "kubeadmin", and password: "xxxxx-xxxx-xxxxx-xxxxx"
INFO Time elapsed: 54m40s
```

## Logging in to the disconnected OpenShift
1. via low-side bastion
```
$ ssh lowside
$ oc login -u kubeadmin -p xxxxx https://api.xxxx.sandboxXXXX.opentlc.com:6443
```
2. via vncviewer
```
$ ssh -L 5900:localhost:5900 -N -f lab-user@jumphost.sandboxXXXX.opentlc.com
$ vncviewer localhost
```