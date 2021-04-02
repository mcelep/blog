#!/usr/bin/env python3

import sys
from datetime import datetime
import json
import subprocess


def process_pods(ns, pod_names):
    capture_metadata = {"pod_metadata": []}
    for pod in pod_names:
        capture_metadata["pod_metadata"].append({"pod": pod, "file": '{}.pcap'.format(pod), "IP": find_pod_ip(ns, pod)})

    capture_metadata["services"] = json.loads(lookup_service_data(ns))
    capture_metadata["pods"] = json.loads(lookup_pod_data(ns))
    capture_metadata["rs"] = json.loads(lookup_rs(ns))
    capture_metadata["deployments"] = json.loads(lookup_deployments(ns))

    capture_metadata_filepath = ".tmp/capture-{}.json".format(datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))
    with open(capture_metadata_filepath, "w") as a_file:
        a_file.write(json.JSONEncoder().encode(capture_metadata) + '\n')


def find_pod_ip(ns, pod):
    return subprocess.check_output("""kubectl -n {} get pods {} -o jsonpath='{{.status.podIP}}' """.format(ns, pod),
                                   shell=True, timeout=60, stderr=None).decode("utf-8")


def lookup_service_data(ns):
    return subprocess.check_output("""kubectl -n {} get svc -o json""".format(ns),
                                   shell=True, timeout=60, stderr=None).decode("utf-8")


def lookup_pod_data(ns):
    return subprocess.check_output("""kubectl -n {} get pod -o json""".format(ns),
                                   shell=True, timeout=60, stderr=None).decode("utf-8")


def lookup_rs(ns):
    return subprocess.check_output("""kubectl -n {} get rs -o json""".format(ns),
                                   shell=True, timeout=60, stderr=None).decode("utf-8")


def lookup_deployments(ns):
    return subprocess.check_output("""kubectl -n {} get deployments -o json""".format(ns),
                                   shell=True, timeout=60, stderr=None).decode("utf-8")


def main(argv):
    if len(argv) == 0:
        print('Provide at least one argument / pod name!')
        sys.exit(2)
    process_pods(argv[0], argv[1:])


if __name__ == '__main__':
    main(sys.argv[1:])
