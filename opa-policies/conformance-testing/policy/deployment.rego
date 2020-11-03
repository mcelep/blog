package deployment

warn_at_least_2_replicas[msg] {
  input.kind == "Deployment"
  2>input.spec.replicas
  msg := "There must be at least 2 replicas of a deployment"
}

warn_readines_probe[msg] {
  input.kind == "Deployment"
  containers = input.spec.template.spec.containers[_]
  not has_key(containers,"readinessProbe")
  msg := "There must be a readinessProbe for each container"
}

warn_liveness_probe[msg] {
  input.kind == "Deployment"
  containers = input.spec.template.spec.containers[_]
  not has_key(containers,"livenessProbe")
  msg := "There must be a livenessProbe for each container"
}

warn_resources[msg] {
  input.kind == "Deployment"
  containers = input.spec.template.spec.containers[_]
  not has_key(containers,"resources")
  msg := "There should be a resources element defined for each container"
}

warn_resource_limits[msg] {
  input.kind == "Deployment"
  containers = input.spec.template.spec.containers[_]
  resource = containers["resources"]
  not has_key(resource,"limits")
  msg := "There should be a limits element set for resources for each container"
}

warn_resource_requests[msg] {
  input.kind == "Deployment"
  containers = input.spec.template.spec.containers[_]
  resource = containers["resources"]
  not has_key(resource,"requests")
  msg := "There should be a requests element set for resources for each container"
}

warn_affinity["Pod affinity rules should have been set"]{
  input.kind == "Deployment"
  pod = input.spec.template.spec
  not has_key(pod,"affinity")
}

warn_affinity_pod_anti_affinity["Pod podAntiAffinity rules should have been set"]{
  input.kind == "Deployment"
  affinity = input.spec.template.spec.affinity
  not has_key(affinity,"podAntiAffinity")
}

# This function is from https://blog.kenev.net/posts/check-if-key-exists-in-object-in-rego-42pp
has_key(x, k) { _ = x[k] }



