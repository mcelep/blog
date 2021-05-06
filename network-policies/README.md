---
title: Lifecycle of Kubernetes Network Policies 
tags: ['kubernetes', 'NetworkPolicy','automation','network']
status: draft
---
# Lifecycle of Kubernetes Network Policies

In this blog post, we will talk about the whole lifecycle of Kubernetes Network Policies covering topics such as creation, editing, governance, debugging and we will also share insights which can create better user experiences when dealing with Network Policies.

## Enter Network Policies

As Kubernetes continues to get adapted more in large Enterprises, security relevant aspects of Kubernetes such as Network Policies, which lets you to control what network resources are allowed to be accessed from/to Pods, become more important.

Kubernetes is a very powerful platform and with all that power some complexity is also introduced. Especially folks who've just started to learn about Kubernetes, can get overwhelmed due to all the new things they will need to interact with and master. Kubernetes after all is supposed to help companies become more nimble but a platform alone can't fix most typical problems of enterprises such as culture, processes and silos. Even if your company has the best Kubernetes platform, if you don't integrate it well to the rest of the IT ecosystem of an Enterprise, you will never be able to get the full benefits of a Kubernetes platform.

Unfortunately, many large enterprises that adopt Kubernetes, suffer from the fact that the organization as a whole is not very agile. In the average large enterprise today, unfortunately there is still a lot of manual work that needs to happen for any IT related order/change to complete. Often Network/Security teams are isolated from the Platform & Application teams from a organizational perspective and the 'silo' mentality together with each organizational unit having its own targets & incentives, security related topics often become big sources of problems and slowness.

Network Policies, which play a very critical component for network security, are only as good as the user experience around them such as how easy it is to create them? how easy it is to have them approved & applied? In the rest of this blog post, we will talk about some ideas that target different stages of Network Policies that should help you to create an optimal user experience around using Network Policies.

## A Pattern: Network Perimeter Security Delegation to Kubernetes

One pattern that helps a lot in many Enterprises, is opening communication (at least for some common services such as a logging service, monitoring service) all the way to perimeters of the Kubernetes Clusters and then let Network Policies control the network traffic. When a team needs to manage Network Policies and at the same request new Firewall rules via different mechanisms such as ServiceNow or some other workflow/ticketing system, the total turnaround time for getting the Network access just takes too much time. The main motivation behind this pattern is doing the lengthy Firewall changes just once and on a Kubernetes platform level and rely on Network Policies for the fine-grained control.

![A Pattern: Network Perimeter Security Delegation to Kubernetes](https://github.com/mcelep/blog/blob/397bbb672a302f1a0b4b9dcf9883912d258ceebc/network-policies/network_perimeter_kubernetes.png?raw=true)

When the Network Perimeter Security is controlled on the Kubernetes cluster level, the default allowed traffic will need to be controlled carefully i.e. you will probably want to limit what ingress / egress network traffic is allowed by default. One should bear in mind that, when no Network Policy is applied on a namespace, Kubernetes exercises no control for the network traffic. This can be done in different ways depending on the [CNI(Container Network Interface)](https://github.com/containernetworking/cni) plugin used in a Kubernetes cluster. One way of doing it would be to apply a Network Policy that blocks most of the egress/ingress traffic for all Namespaces and control RBAC(role based access control) in such a way that non-admin users of Kubernetes clusters can't create/edit/delete Network Policy objects themselves without some governance. Based on the software that implements CNI plugin that your clusters use, you might also need to limit what network access each namespace gets by default. Using [NSX](https://www.vmware.com/products/nsx.html) firewall rules to implement this idea is something we know from the field at VMware Tanzu Labs.

 At the same, for such a pattern to work successfully, the turnaround time for applying Network Policies should be as short as possible. In the Governance section of the post, a couple of ideas about how governance can be shaped so that Network Policies can be accepted or rejected as quickly as possible.

## Creating Network Policies

### Basics

It's key to have a basic understanding about Network policies, and the two documents below are very good starting points:

- [Kubernetes official documentation about Network Policies]( https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [A tutorial from Kubernetes Network Policy Community](https://github.com/networkpolicy/tutorial)

Once you've understood the basics, it's probably time to get some hands-on experience. See if you can install your favorite CNI plugin that supports Network Policies on [minikube](https://minikube.sigs.k8s.io/docs/) or another Kubernetes cluster you can access. If you have to install a CNI plugin yourself, you would require admin rights. It's important here to note that although Network Policy is an official part of Kubernetes and a standard Kubernetes resource, it's the CNI plugin that actually 'implements' the Network Policies, so as long as a CNI tool supports Network Policies, you should be able to test the basic functionality of Network Policies. That said, vanilla Kubernetes Network Policies have certain limitations as explained [here](https://kubernetes.io/docs/concepts/services-networking/network-policies/#what-you-can-t-do-with-network-policies-at-least-not-yet) so it makes a lot of sense, if possible, to test out Network Policies using the actual CNI plugin you would use in production.

If you desire to see a good catalogue of example Network Policies that cover most of the use cases, check out [this github repo](https://github.com/ahmetb/kubernetes-network-policy-recipes).

Another important point to consider is how you deal with pod selectors for Network Policies. A key called ```spec.podSelector``` controls to which policies the Network Policy will be applied on. When the key is empty, i.e. ```  podSelector: {}``` , it applies to all pods in the namespace where the Network Policy is created. If you want to target specific pods, you can do it by using a pod selector such as:
```
  podSelector:
    matchLabels:
      app: bookstore
```      
If you have lots of NetworkPolicies to write because your app has many components and if you want to write a policy that controls traffic as precisely as possible meaning writing pod selectors that only targets the pods where a specific egress/ingress rule is required, you can use a key called **matchExpressions**. See the example below which helps you to target two different kinds of pods via labels *app=bookstore* or *app=database*:
```
  podSelector:
    matchExpressions:
      - {key: app, operator: In, values: [bookstore, database]}
```      

#### DNS

Forgetting adding a **Network Policy for DNS** calls is another common mistake. Depending on how your pod is configured as explained [here](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/#pod-s-dns-policy), application pods might need to communicate to the DNS server running on your cluster or a DNS server running outside. Make sure to add a Network Policy to accommodate DNS communication needs to your namespace. If your CNI plugin allows it you can do also apply a DNS policy on the cluster level, e.g. with [Antrea's ClusterNetworkPolicy](https://github.com/vmware-tanzu/antrea/blob/28ef522ced7045f567c22b916cb29d9272f9c92b/docs/antrea-network-policy.md).

#### Pod A's Egress is Pod B's Ingress 

If **Pod A** needs to call **Pod B**, you will need to create a Network Policy that has **egress** rules for **Pod A** and another Network Policy that has **ingress** rules for **Pod B**. It's quite common to forget this symmetry requirement between egress & ingress rules for communication between Pods.


### Editing Network Policies

"Kubernetes and YAML in everybody's mind really go together" says Joe Beda, one of the co-creators of Kubernetes, in [this talk](https://www.youtube.com/watch?v=8PpgqEqkQWA). And he's right, it's the recommended way of writing configuration files as you can see [here](https://kubernetes.io/docs/concepts/configuration/overview/) and most of the folks that I've worked with use YAML (instead of JSON). If I got a penny for every time I saw someone break indentation in a YAML file, I would be rich by now :).  So do yourself a favor and use an editor with a plugin that helps you notice/fix these issues easily. Basic YAML syntax support will definitely help a lot, if you can get a plugin that also understand Kubernetes YAML syntax even better! Improved Kubernetes YAML editing experience will not only help for Network Policies obviously, you can improve the whole Kubernetes experience by a more pleasant resource editing experience. Here are some tips:

- [Here](https://www.youtube.com/watch?v=eSAzGx34gUE) is a video and [here](https://octetz.com/docs/2020/2020-01-06-vim-k8s-yaml-support/) is a blog post that shows how you can do it with Vim.
  
- If Visual Studio Code is your editor of choice, you might want to look into [this plugin](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml)

- For most of the editors you should be able to get at least YAML syntax support so go ahead install a plugin or update your editor config so that YAML support is activated.

[Cilium editor](https://editor.cilium.io/) is a tool to create the Network Policies with a graphical editor. Especially when beginning writing Network Policies, the visual interaction might be very helpful. Below is a snapshot from the cilium editor:
![Cilium Editor](https://github.com/mcelep/blog/blob/397bbb672a302f1a0b4b9dcf9883912d258ceebc/network-policies/cilium-editor.png?raw=true)

For an application that includes many different kinds of components e.g. a micro-service application, writing a lot of Network Policies manually can be quite cumbersome. If your application is COTS(Commercially Available Off the Shelf) software, perhaps the software should provide all the Network Policies and keep them up to date as the Software and its components evolve.

[This blog](https://itnext.io/generating-kubernetes-network-policies-by-sniffing-network-traffic-6d5135fe77db) talks about an idea about how you can automatically generate Network Policies based on actual application network traffic.

## Governance

Although Network Policies are well defined Kubernetes resources, there might be certain things that your company wants to enforce that is specific to them due to regulatory/auditing purposes. For example, certain annotations that might provide more information about the context of a Network Policy might be a thing security department wants to enforce, e.g an annotation such as *k8s.example.com/projectId* in metadata section of the Network Policy. In such a case, it becomes critical to document the expectation, provide examples of good Network Policies and let platform users know about the documentation.


### Git Pull Requests To The Rescue


In most of the environments where you would require Network Policies, there will typically be a process around getting the Network Policies applied on a kubernetes cluster. Such process could be some sort of an approval/auditing process and users will not be authorized to edit Network Policies themselves directly. One very common way of doing this is implementing an audit process based on Git repositories. The typical flow in such a setup looks like this:

- A developer checks out the Git repo where the Network Policies reside
- Developer creates a new branch and works on editing/creating Network Policies
- Developer creates a pull request based on his branch
- Security experts need to approve or reject the Pull request and provide enough information about why if they reject a pull request
- If a pull request gets approved, a pipeline picks up the change and applies it on the cluster, developer gets notified.

The steps above capture the gist of a Git pull request process. Compared to a traditional model in which there would be a ticket opened in a system such as ServiceNow, there might be some improvements. For example, instead of using some free text or some other format to capture data, users end up creating the Network Policy in a way that can be directly used on Kubernetes clusters. Ideally, automation should be used as much as possible to make sure Network Policy requests are processed as correctly and as quickly as possible.

In the next section, we will go into details of how Network Policies creation can be fully automated without any human interaction and GIT. Using something like [Gatekeeper](https://github.com/open-policy-agent/gatekeeper) and security folks letting the whole process be fully automated, is sometimes too big of a conceptual change i.e. folks who are responsible for security must understand and potentially collaborate in the implementation of this automation. Using a Git based approach with at least some automation, might already give you loads of benefits and improve the time to production significantly. Ideas below could be embedded into your Git Pull Requests based process:

- It's very easy to make mistakes when writing yaml files, so the first thing to do is to make sure that incoming Pull requests contains valid Network Policies. Use ```--dry-run``` parameter with ```kubectl apply``` or ```kubectl create```, to see if a Network Policy resource file is valid. The earlier you catch a validation error in the process, the cheaper it is to fix.

- Maybe you can't automatically approve all the incoming Network Policies via automation but you can at least use some useful insights about the incoming network profile by checking if the IP ranges are allowed, if there are any cross namespace requests, etc. So it might need to be a human that needs to do final approval of a Network Policy, but his work can be simplified by relatively cheap automation. [OPA(Open Policy Agent)](https://www.openpolicyagent.org/docs/latest/) with its [Rego](https://www.openpolicyagent.org/docs/latest/#rego) DSL can help here to write some automation or simply use your favorite (scripting) language to parse Network Policy files and evaluate them towards a bunch of rules that you create based on your organization's needs.

### OPA/Gatekeeper based fully automated control of Network Policy creation

[Open Policy Agent(OPA)](https://www.openpolicyagent.org/) is a Cloud Native Computing Foundation project and it aims at solving 'policy enforcement' problem across the Cloud-Native stack(Kubernetes, Docker, Envoy, Terraform, etc.). OPA comes with a language called [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) to author policies efficiently and other than Rego, there are a number of tools & components in OPA to make use of policies easier & efficient.

The quickest way auditing Network Policies automatically can be implemented directly on a K8S cluster. OPA comes with a component called [Gatekeeper](https://www.openpolicyagent.org/docs/latest/kubernetes-introduction/). Gatekeeper is an Admission Controller, and it aims at managing and enforcing policies easily on K8S clusters. That is, one can hook into [Admission Controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) mechanism of Kubernetes to reject K8S Resource modifications that are not allowed by policies. By writing *Rego* policies that control what Network Policies are allowed and rejected, a developer will have very quick feedback regarding which network traffic is allowed. OPA and Gatekeeper are very interesting technologies that are getting popular in the Kubernetes ecosystem and it's definitely worth to invest a bit of time to understand it better. We are planning to provide a more practical example of how you can use Rego to control Network Policies in another article.

## Debugging

Another important stage while using Network Policies is debugging your Network Policies. Complex applications typically communicate with many endpoints over the network and it might be sometimes time-consuming & difficult to pinpoint which missing or misconfigured Network Policy is the culprit when application runs into errors. In such a case, application logs should provide some insights. However, depending on the quality of application logs or availability of log searching tools, just logs might not be sufficient. In such a case networking tools are likely to provide the most help.

Running a tool like tcpdump on Kubernetes nodes where the target application pods are running, might come in very handy. You can run tcpdump as a sidecar to your application pods or run tcpdump on a Kubernetes node's interface and apply the necessary filters. [This post](https://itnext.io/generating-kubernetes-network-policies-by-sniffing-network-traffic-6d5135fe77db) and [this one](https://xxradar.medium.com/how-to-tcpdump-effectively-in-kubernetes-part-1-a1546b683d2f) should give you an idea about how it can be done.

Moreover, depending on the CNI tool that you use, you might be able to extract useful information from CNI software directly. For NSX-T users, [this](https://blogs.vmware.com/management/2019/06/kubernetes-insights-using-vrealize-network-insight-part-1.html) might come in handy, and for Cilium there are some nice tools too, see [here](https://docs.cilium.io/en/v1.9/policy/troubleshooting/#policy-tracing) and [here](https://github.com/cilium/hubble). For Antrea, you might want to checkout [this](https://github.com/vmware-tanzu/antrea/blob/main/docs/network-flow-visibility.md) and for IpTable relevant issues [this](https://github.com/box/kube-iptables-tailer).