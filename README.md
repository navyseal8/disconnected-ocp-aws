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
Make sure download 4.19.17
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

## Mirror registry and operators to disk

1. Create imageset-config.yaml to your specific OpenShift version.
2. Select the operators you need for mirror by referencing against the catalog index image

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

## Prepare registry 

## diskToRegistry mirror

## Install disconnected OpenShift

