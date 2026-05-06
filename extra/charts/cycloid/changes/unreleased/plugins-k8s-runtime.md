## Added

- Plugin Manager: support `deploymentRuntime: k8s` to run plugin containers as Kubernetes pods instead of requiring a privileged containerd socket. Includes automatic RBAC, ServiceAccount, Namespace creation, and db-proxy sidecar configuration.
- Plugin Registry: support `workerRuntime: k8s` to expand plugin versions using Kubernetes pods instead of containerd.
