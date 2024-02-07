# Cycloid on-premises on Kubernetes

The Cycloid on-premises setup on Kubernetes provide a way to setup the Cycloid platform and dependencies within your own Kubernetes cluster.

This setup is provided as a [Helm chart](https://helm.sh/docs/topics/charts/) which is kind of the de facto standard to package applications for Kubernetes.

This chart is accessible from a public Helm repository hosted on AWS S3.

To run it, you will need to get from Cycloid Scaleway credentials to access our private docker registry.

**Note!** Optionally you can use the AWS credentials to access our private ECR in case of an issue with Scaleway credentials. To do this simple change the registry in the values and enable the renewToken option.

Documentation [here](https://docs.cycloid.io/onprem/k8s.html)
