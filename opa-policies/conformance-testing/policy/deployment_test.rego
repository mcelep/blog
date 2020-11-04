package deployment

deployment_1_replica := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 1, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"requests": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_2_replica := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"requests": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

test_1_replica_warned {
	warn_at_least_2_replicas with input as deployment_1_replica
}

test_2_replica_allowed {
	not warn_at_least_2_replicas["There must be at least 2 replicas of a deployment"] with input as deployment_2_replica
}

deployment_with_readiness := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_without_readiness_liveness := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always"}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_with_liveness := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

test_readiness_warned {
	warn_readines_probe with input as deployment_without_readiness_liveness
}

test_readiness_probe_allowed {
	not warn_readines_probe["There must be a readinessProbe for each container"] with input as deployment_with_readiness
}

test_liveness_allowed {
	not warn_liveness_probe["There must be a livenessProbe for each container"] with input as deployment_with_readiness
}

test_liveness_warned {
	warn_liveness_probe with input as deployment_without_readiness_liveness
}

deployment_with_resources := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"limits": {"cpu": 1, "memory": "256Mi"}, "requests": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_without_resources := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_without_resource_limits := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"requests": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

deployment_without_resource_requests := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"limits": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

test_resources_allowed {
	not warn_resources["There should be a resources element defined for each container"] with input as deployment_with_resources
}

test_resources_warned {
	warn_resources["There should be a resources element defined for each container"] with input as deployment_without_resources
}

test_resources_limits_warned {
	warn_resource_limits with input as deployment_without_resource_limits
}

test_resources_requests_warned {
	warn_resource_limits with input as deployment_without_resource_requests
}

deployment_with_anti_affinity := {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"labels": {"app": "nginx"}, "name": "nginx"}, "spec": {"progressDeadlineSeconds": 600, "replicas": 2, "revisionHistoryLimit": 10, "selector": {"matchLabels": {"app": "nginx"}}, "strategy": {"rollingUpdate": {"maxSurge": "25%", "maxUnavailable": "25%"}, "type": "RollingUpdate"}, "template": {"metadata": {"labels": {"app": "nginx"}}, "spec": {"affinity": {"podAntiAffinity": {"requiredDuringSchedulingIgnoredDuringExecution": [{"labelSelector": {"matchExpressions": [{"key": "app", "operator": "In", "values": ["nginx"]}]}, "topologyKey": "kubernetes.io/hostname"}]}}, "containers": [{"image": "nginxinc/nginx-unprivileged", "imagePullPolicy": "Always", "livenessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "readinessProbe": {"failureThreshold": 3, "httpGet": {"path": "/", "port": 8080, "scheme": "HTTP"}, "periodSeconds": 10, "successThreshold": 1, "timeoutSeconds": 1}, "resources": {"limits": {"cpu": 1, "memory": "256Mi"}, "requests": {"cpu": 1, "memory": "256Mi"}}}], "dnsPolicy": "ClusterFirst", "restartPolicy": "Always", "schedulerName": "default-scheduler", "terminationGracePeriodSeconds": 30}}}}

test_with_anti_affinity_allowed {
	not warn_affinity["Pod affinity rules should have been set"] with input as deployment_with_anti_affinity
	not warn_affinity_pod_anti_affinity["Pod podAntiAffinity rules should have been set"] with input as deployment_with_anti_affinity
}
