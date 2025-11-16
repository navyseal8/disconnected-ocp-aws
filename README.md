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
3. Provision template (using cloudformation.yaml)

## AWS Architecture



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

1. Create imageset-config.yaml to your specific OpenShift version.
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


## Prepare registry (At the Highside Host)

1. Rsync the contents over to Highside host
```
$ rsync -avP /mnt/low-side-data/mirror-registry-amd64.tar.gz highside:/mnt/high-side-data/

$ ssh highside
$ cd /mnt/high-side-data
$ tar -xzvf mirror-registry-amd64.tar.gz
image-archive.tar
execution-environment.tar
mirror-registry
sqlite3.tar

```

## diskToRegistry mirror

## Install disconnected OpenShift

