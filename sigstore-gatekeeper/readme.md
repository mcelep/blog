---
title: Enforcing policies in Kubernetes
tags: ['kubernetes', 'opa', 'rego', 'policy', 'policy enforcement']
status: draft
---

## Intro

[As software keeps eating the world](https://a16z.com/2011/08/20/why-software-is-eating-the-world/),  and software becomes a critical part of more and more businesses, cybersecurity risks also increase significantly. For a company to run its IT operations securely, running [a secure software supply chain](https://www.synopsys.com/glossary/what-is-software-supply-chain-security.html)is a must. Companies that develop their own software using Open Source software need to be even more alert to cybersecurity threats.

Containers are one of the most common ways to package applications these days and Kubernetes is one of the most popular ways to run containers (link some research). Running containers in Kubernetes clusters securely is a big topic. There are many angles one has to consider on Kubernetes level: network access (e.g. see [this](https://itnext.io/lifecycle-of-kubernetes-network-policies-749b5218f684) blog post), service accounts, pod security admission(or its predecessor pod security policies),etc. Moreover, there are also many angles to consider when focusing on the container image side. For this blog post though, the questions that we are going to focus on for container image security are:

-   Was the container image tempered with before it reached the Kubernetes cluster? 

-   Who owns the container image?

## A useful framework: SLSA

[SLSA](https://slsa.dev/) is a good framework to think about software supply chain security; the image diagram below depicts the things that could go wrong in different stages. Stage G (Compromise package repo) & stage H (Use compromised package) are going to be relevant for our discussion.

![supply chaing diagram](https://github.com/mcelep/blog/blob/master/sigstore-gatekeeper/SupplyChainDiagram.png?raw=true)

The actual binaries included in a container are an extremely important part of the `running containers securely in kubernetes` puzzle. The vulnerabilities coming from packages in a container can be scanned by tools such as snyk(container), trivy, clair, syft and as interesting as this topic is, this post will not go into the details of container image scanning.

## Trust, but verify


As [devsecops](https://www.devsecops.org/) becomes more popular, methods of [shifting left](https://en.wikipedia.org/wiki/Shift-left_testing) and having a more developer-friendly and developer-inclusive approach to security is also gaining momentum thanks to companies such as [Synk](https://snyk.io/). That said, this author thinks that a `trust, but verify` approach is still the key to having good cybersecurity. Developers/operators should have tools & means to fix vulnerabilities as early as possible in their software development cycles but whenever possible there should also be means to automatically block users from taking risky actions all the way to production.

Thanks to the admission[ controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) mechanism in Kubernetes, there is a good way to NOT allow resources on Kubernetes API if they do not fulfill certain requirements. One can create their own admission webhooks and configure Kubernetes clusters to trigger these webhooks or rely on generalized policy based approaches. As of October 2022, [OPA gatekeeper](https://github.com/open-policy-agent/gatekeeper) and [Kyverno](https://kyverno.io/) are the most popular policy based kubernetes admission solutions.

With a policy based admission control mechanism, you can mitigate the risk that is exposed in stage H (Use compromised package) from the diagram above. The other point to think about is Stage G (Compromise package repo). However instead of focusing on a compromised package repo, I would like to focus on how we can verify the authenticity of a package and avoid using a compromised package. In order to verify that a package - a container image in our case - was really built by an actor that you trust, a notary mechanism can be used. [Sigstore](https://github.com/sigstore) brings such a notary mechanism to the table that we can directly use with container images on Kubernetes.

[Connaisseur](http://connaisseur) is a solution that combines admission control and signature verification into a single component; it's probably a topic for another blog post though.

## Sigstore and OPA Gatekeeper

Let's look into an example of how Sigstore and OPA Gatekeeper can be integrated together. 

### Cosign and Fulcio

[Cosign](https://github.com/sigstore/cosign) aims at making container image signing as easy as possible from a key management perspective. It's part of the [sigstore](https://github.com/sigstore) project which provides tools for software supply chain security.

Cosign is nicely documented and it's getting lots of traction in the Kubernetes security domain so we won't be spending lots of time explaining how it works in general but instead we will walk you through a particular use case.

Moreover, we will use another tool from the sigstore family called [Fulcio](https://github.com/sigstore/fulcio). Fulcio will spare us from the trouble of having to manage the private keys ourselves. In many Cosign examples, you will see that a locally generated public/private key pair is used. While this is very useful for getting users started, in enterprise production environments such a solution will not be acceptable. Fulcio helps to abstract away the intricacies of Private Key Infrastructure management(PKI) by integrating with Identity Providers i.e. a user proves his identity to Fulcio and Fulcio, in return, gives the user a certificate that can be used for signing a container image.

### A use case with Cosign And Fulcio

Using Cosign and Fulcio, we will show you here how we can verify that an image is owned/created by a specific subject and its associated identity.

The dependencies for this script are:

-   Golang

-   Docker

-   BASH

[Here](https://github.com/mcelep/blog)'s a script that will:

-   Install cosign via 'go install'

-   Pull the latest nginx container image

-   Push the

-   The identity that is used for signing the image is very important

-   This field is responsible for this image and de. 

-   THe ID should be contacted if the image is to be updated.

-   There are other ways to assign ownership to images.

-   Container image metadata/labels 

-   If namespaces are used for segregation of apps/teams/domains, then namespaces could be used for finding ownership.

-   Having a notary mechanism and deducing the identity is the safest.

-   In most of the examples a self generated CA is used

-   although it is the easiest we want to show that we use a signing mechanism that gets the ID of the signing requestor from a centralized identity provider e.g. Fulcio

Cosign-gatekeeper-provider:

-   Gatekeeper runs OPA , [ExternalData feature](https://open-policy-agent.github.io/gatekeeper/website/docs/externaldata) provides an easy way to call external functions(things that might be difficult to do in Rego and built-ins are missing)
