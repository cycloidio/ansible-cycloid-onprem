# Cycloid on-premises on Kubernetes

The Cycloid on-premises setup on Kubernetes provide a way to setup the Cycloid platform and dependencies within your own Kubernetes cluster.

This setup is provided as a [Helm chart](https://helm.sh/docs/topics/charts/) which is kind of the de facto standard to package applications for Kubernetes.

This chart is only accessible from a private Helm repository hosted on AWS S3.

To access and run it, you will need to get from Cycloid AWS credentials to access our Helm repository and private docker registry.

Documentation [here](https://docs.cycloid.io/onprem/k8s.html)
