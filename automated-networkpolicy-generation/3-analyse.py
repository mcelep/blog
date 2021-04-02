#!/usr/bin/env python3
import sys
import subprocess
import logging
import json
import os
import shutil

from enum import Enum
from dataclasses import dataclass
from typing import Sequence

from graph_tools import Graph
from kubernetes import client
from kubernetes.client import V1IPBlock

map_ip_2_svc = {}
map_name_2_pod = {}
map_name_2_rs = {}
map_name_2_deployments = {}

g = Graph()
logger = logging.getLogger('traffic_analyser')

EDGE_ATTRIBUTE_PORT_ID = 0
EDGE_ATTRIBUTE_PORT_NAME = 'ports'
VERTEX_ATTRIBUTE_POD = 'pod'

include_ingress_in_policy = True
include_egress_in_policy = True
create_dns_policy = True


def process_file(file):
    base_folder = file[: file.rindex('/')]
    with open(file, "r") as a_file:
        capture_metadata = json.loads(a_file.read())
        build_service_map(capture_metadata["services"]["items"])
        build_pod_map(capture_metadata["pods"]["items"])
        build_rs_map(capture_metadata["rs"]["items"])
        build_deployments_map(capture_metadata["deployments"]["items"])
        for pod_metadata in capture_metadata["pod_metadata"]:
            handle_capture_per_pod(pod_metadata["pod"],  base_folder + '/' + pod_metadata["file"],
                                   pod_metadata["IP"])

    print_graph()
    result = create_network_policy()
    policy_folder = base_folder + '/network-policies'
    create_clean_policies_directory(policy_folder)
    for policy in result:
        policy_content = client.ApiClient().sanitize_for_serialization(policy)
        with open(policy_folder + '/network_policy_{}.json'.format(policy_content["metadata"]["name"]), "w") as policy_file:
            policy_file.write(json.dumps(policy_content, indent=4))


def create_clean_policies_directory(dir):
    try:
        shutil.rmtree(dir, ignore_errors=True, onerror=None)
    except:
        logger.warning('Error removing dir:{}'.format(dir))
    os.mkdir(dir)


def build_service_map(service_items):
    for svc in service_items:
        map_ip_2_svc[svc["spec"]["clusterIP"]] = svc


def build_pod_map(pod_items):
    for pod in pod_items:
        map_name_2_pod[pod["metadata"]["name"]] = pod


def build_rs_map(rs_items):
    for rs in rs_items:
        map_name_2_rs[rs["metadata"]["name"]] = rs


def build_deployments_map(deployment_items):
    for d in deployment_items:
        map_name_2_deployments[d["metadata"]["name"]] = d


def handle_capture_per_pod(pod_name, capture_file_path, pod_ip):
    logger.debug('Pod: {}, Capture: {}, IP: {}'.format(pod_name, capture_file_path, pod_ip))
    result = subprocess.check_output(
        """ tshark -r {} -Y " ip.src == {} && tcp.flags.syn==1 && tcp.flags.ack==0 && not icmp" -Tfields \
          -eip.dst_host  -e tcp.dstport -Eseparator=, | sort --unique """.format(
            capture_file_path, pod_ip), shell=True, timeout=60, stderr=None).decode("utf-8")
    process_stdout_from_tshark(pod_name, result)


def process_stdout_from_tshark(pod_name, result):
    if not result or len(result) == 0:
        logger.info("Empty response!")
        return

    target_hosts = result.split("\n")
    for target_host in target_hosts:
        if len(target_host) == 0:
            continue
        parts = target_host.split(",")
        target_ip = parts[0]
        target_port = parts[1]
        logger.debug('IP:{}, Port:{}'.format(target_ip, target_port))
        push_edge_information(pod_name, target_ip, target_port)


@dataclass(frozen=True, eq=True, order=True)
class NodeType(Enum):
    POD = 1
    IP = 2
    FQDN = 3


@dataclass(frozen=True, eq=True, order=True)
class Node:
    type: NodeType
    name: str
    id: str

    def __repr__(self):
        return '<%s: %s>' % (
            self.type.name, self.name)


def push_edge_information(source_pod_name, target_ip, target_port):
    logger.info('Source Pod:{}, Destination IP:{}, Destination Port:{}'.format(source_pod_name, target_ip, target_port))
    if target_ip.startswith('169.254'): # Ignore link-local address, https://en.wikipedia.org/wiki/Link-local_address
        logger.info('Skipping ip: {}'.format(target_ip))
        return

    target = None
    target_pod_name = None
    source = None

    if map_ip_2_svc.keys().__contains__(target_ip):
        target_pod_name = find_pods_that_resolves_to_svc(map_ip_2_svc[target_ip])
    else:
        logger.info('No service found for IP:{}'.format(target_ip))
        target_pod_name = find_pod_with_ip(target_ip)

    if target_pod_name is None or target_pod_name == '':
        logger.warning('No target svc or pod found for IP: {}, assuming that this is an external IP.'.format(target_ip))
        target = Node(NodeType.IP, target_ip , target_ip)
    else:
        target = Node(NodeType.POD, look_up_owner_name(target_pod_name), target_pod_name)

    source = Node(NodeType.POD, look_up_owner_name(source_pod_name), source_pod_name)
    g.add_vertex(source)

    
    g.add_vertex(target)
    g.add_edge(source, target)
    # Add port to edge properties
    existing = None
    try:
        existing = g.get_edge_attribute_by_id(source, target, EDGE_ATTRIBUTE_PORT_ID, EDGE_ATTRIBUTE_PORT_NAME)
    except:
        logger.warning("Edge attribute not found, source:{}, target: {}", source, target)
    if not existing:
        existing = []
    existing.append(target_port)
    g.set_edge_attribute_by_id(source, target, EDGE_ATTRIBUTE_PORT_ID, EDGE_ATTRIBUTE_PORT_NAME, existing)


def find_pod_with_ip(ip):
    for pod in map_name_2_pod.values():
        if pod["status"]["podIP"] == ip:
            return pod["metadata"]["name"]
    return ''


def create_network_policy():
    result = []
    for v in g.vertices():
        # Only handle pods, other types should be handled as dependencies with their relation to pods
        if v.type is not NodeType.POD:
            continue

        network_policy: client.models.V1NetworkPolicy = None
        if include_egress_in_policy:
            for egress in g.edges_from(v):
                logger.debug("Egress from edge: {}", egress)
                ports = g.get_edge_attribute_by_id(egress[0], egress[1], EDGE_ATTRIBUTE_PORT_ID, EDGE_ATTRIBUTE_PORT_NAME)
                if network_policy is None:
                    network_policy = create_network_policy_skeleton(v)
                if network_policy.spec.egress is None:
                    network_policy.spec.egress = []
                network_policy.spec.egress.append( client.models.V1NetworkPolicyEgressRule(
                    ports=create_network_policy_ports(ports)))
                if network_policy.spec.egress[len(network_policy.spec.egress) -1]._to is None:
                    network_policy.spec.egress[len(network_policy.spec.egress) -1]._to = []
                network_policy.spec.egress[len(network_policy.spec.egress) -1]._to.append(create_network_policy_peer(egress[1]))

        if include_ingress_in_policy:
            for ingress in g.edges_to(v):
                logger.debug("Ingress to  edge: {}", ingress)
                ports = g.get_edge_attribute_by_id(ingress[0], ingress[1], EDGE_ATTRIBUTE_PORT_ID, EDGE_ATTRIBUTE_PORT_NAME)
                if network_policy is None:
                    network_policy = create_network_policy_skeleton(v)
                if network_policy.spec.ingress is None:
                    network_policy.spec.ingress = []
                network_policy.spec.ingress.append(client.models.V1NetworkPolicyIngressRule(
                        ports=create_network_policy_ports(ports)))
                if network_policy.spec.ingress[len(network_policy.spec.ingress) -1]._from is None:
                    network_policy.spec.ingress[len(network_policy.spec.ingress) -1]._from = []
                network_policy.spec.ingress[len(network_policy.spec.ingress) -1]._from.append(create_network_policy_peer(ingress[0]))

        update_policy_types(network_policy)
        result.append(network_policy)

    if create_dns_policy:
        result.append(create_dns_network_policy())

    return result


def create_dns_network_policy():
    np = client.models.V1NetworkPolicy(api_version='networking.k8s.io/v1', kind='NetworkPolicy',metadata=client.models.V1ObjectMeta(name='dns'))
    np.spec = client.models.V1NetworkPolicySpec(pod_selector={})
    np.spec.egress = []
    np.spec.egress.append(client.models.V1NetworkPolicyEgressRule(ports=[client.models.V1NetworkPolicyPort(protocol='TCP', port=53),
                                                                         client.models.V1NetworkPolicyPort(protocol='UDP', port=53)]))
    update_policy_types(np)
    return np


def create_network_policy_peer(node: Node):
    if node.type is NodeType.POD:
        return client.models.V1NetworkPolicyPeer(
            pod_selector=look_up_pod_selector(node.id))
    elif node.type is NodeType.IP:
        return client.models.V1NetworkPolicyPeer(ip_block = V1IPBlock(cidr = node.id + "//32"))
    else:
        raise Exception("Not implemented logic for NodeType:{}", node.type)


def update_policy_types(np: client.models.V1NetworkPolicy):
    np.spec.policy_types = []
    if np.spec.ingress is not None:
        np.spec.policy_types.append("Ingress")
    if np.spec.egress is not None:
        np.spec.policy_types.append("Egress")


def create_network_policy_ports(ports: Sequence):
    result = []
    for port in ports:
        result.append(client.models.V1NetworkPolicyPort(protocol='TCP', port=int(port)))
    return result


def create_network_policy_skeleton(v: Node):
    assert v.type == NodeType.POD
    pod_data = find_pod_from_name(v.id)
    if pod_data is None:
        raise Exception("No pod data found for vertex:{}", v)
    # TODO fix the name of NetworkPolicy
    network_policy = client.models.V1NetworkPolicy(api_version='networking.k8s.io/v1', kind='NetworkPolicy',
                                                   metadata=client.models.V1ObjectMeta(name=look_up_owner_name(v.id)))
    network_policy.spec = client.models.V1NetworkPolicySpec(
        pod_selector=look_up_pod_selector(pod_data['metadata']['name']))
    return network_policy


def look_up_pod_selector(pod_name):
    selector = client.models.V1LabelSelector()
    pod = find_pod_from_name(pod_name)
    if pod["metadata"]["ownerReferences"]:
        logger.debug('For pod, found this ownerReferences {}', pod_name, pod["metadata"]["ownerReferences"])
        for owner in pod["metadata"]["ownerReferences"]:
            if owner["kind"] == 'ReplicaSet':
                rs = find_rs(owner["name"])
                if rs["metadata"]["ownerReferences"]:
                    for owner1 in rs["metadata"]["ownerReferences"]:
                        if owner1["kind"] == 'Deployment':
                            deployment = find_deployment(owner1["name"])
                            selector.match_labels = deployment["spec"]["selector"]["matchLabels"]
                        else:
                            raise Exception('Unknown kind:{}', owner1)
                else:
                    selector.match_labels = rs["spec"]["selector"]["matchLabels"]
            else:
                raise Exception('Unknown kind:{}', owner)
    else:
        selector.match_labels = pod["metadata"]["labels"]
    return selector


def look_up_owner_name(pod_name):
    pod = find_pod_from_name(pod_name)
    if pod["metadata"]["ownerReferences"]:
        for owner in pod["metadata"]["ownerReferences"]:
            if owner["kind"] == 'ReplicaSet':
                rs = find_rs(owner["name"])
                if rs["metadata"]["ownerReferences"]:
                    for owner1 in rs["metadata"]["ownerReferences"]:
                        if owner1["kind"] == 'Deployment':
                            deployment = find_deployment(owner1["name"])
                            return deployment["metadata"]["name"]
                        else:
                            raise Exception('Unknown kind:{}', owner1)
                else:
                    return rs["metadata"]["name"]
            else:
                raise Exception('Unknown kind:{}', owner)
    else:
        return pod["metadata"]["name"]


def find_pods_that_resolves_to_svc(svc):
    return find_pod_with_labels(svc["spec"]["selector"])


def find_pod_from_name(pod_name):
    return map_name_2_pod[pod_name]


def find_pod_with_labels(labels: dict):
    for p in map_name_2_pod.values():
        if labels.items() <= dict(p["metadata"]["labels"]).items():
            return p["metadata"]["name"]
    raise Exception("Could not find pod with labels:{}".format(labels))


def find_rs(name):
    return map_name_2_rs[name]


def find_deployment(name):
    return map_name_2_deployments[name]


def print_graph():
    print(g)


def main(argv):
    logger.setLevel('DEBUG')
    inputfile = ''
    try:
        inputfile = argv[0]
    except:
        print('3-analyse.py <inputfile>')
        sys.exit(2)
    process_file(inputfile)


if __name__ == '__main__':
    main(sys.argv[1:])
