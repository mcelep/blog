---
title: Container Image Authenticity and Ownership verification
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

## "Trust, but Verify"


As [devsecops](https://www.devsecops.org/) becomes more popular, methods of [shifting left](https://en.wikipedia.org/wiki/Shift-left_testing) and having a more developer-friendly and developer-inclusive approach to security is also gaining momentum thanks to companies such as [Synk](https://snyk.io/). That said, the author thinks that a `trust, but verify` approach is still the key to having good cybersecurity. Developers/operators should have tools & means to fix vulnerabilities as early as possible in their software development cycles but whenever possible there should also be means to automatically block users from executing risky actions aspecially in production.

Thanks to [admission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) mechanism in Kubernetes, there is a good way to NOT allow resources on Kubernetes API if they do not fulfill certain requirements. One can create their own admission webhooks and configure Kubernetes clusters to trigger these webhooks or rely on generalized policy based approaches. As of October 2022, [OPA gatekeeper](https://github.com/open-policy-agent/gatekeeper) and [Kyverno](https://kyverno.io/) are the most popular policy based kubernetes admission solutions.

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

The dependencies for following along our example are:
- Golang
- Docker
- Bash

[Here's](https://github.com/mcelep/blog/blob/master/sigstore-gatekeeper/cosign.sh?raw=true) a script that will:

-   Install cosign via 'go install'
-   Pull the latest nginx container image
-   Push the container image to another repository. Please make sure that you update the value of ```DOCKER_USER``` variable otherwise, the script will fail. 
- Trigger a cosign run that relies on a public Fulcio instance. For our test run we relied on a google account for authentication, you can use another method to authenticate yourself e.g. github.
- Verify the image signature and display the output of the verification.

Below is an example output generated by ``` cosign.sh``` script.
```bash
sh cosign.sh
+ go install github.com/sigstore/cosign/cmd/cosign@latest
+ DOCKER_USER=mcelep
+ docker pull nginx:latest
latest: Pulling from library/nginx
Digest: sha256:0047b729188a15da49380d9506d65959cce6d40291ccfb4e039f5dc7efd33286
Status: Image is up to date for nginx:latest
docker.io/library/nginx:latest
++ docker inspect '--format={{index .RepoDigests 0}}' nginx:latest
+ IMAGE_DIGEST=nginx@sha256:0047b729188a15da49380d9506d65959cce6d40291ccfb4e039f5dc7efd33286
++ echo nginx@sha256:0047b729188a15da49380d9506d65959cce6d40291ccfb4e039f5dc7efd33286
++ cut -d : -f2
+ DIGEST=0047b729188a15da49380d9506d65959cce6d40291ccfb4e039f5dc7efd33286
+ SHORT_DIGEST=0047b729188a
+ docker tag nginx:latest mcelep/nginx:0047b729188a
+ docker push mcelep/nginx:0047b729188a
The push refers to repository [docker.io/mcelep/nginx]
c72d75f45e5b: Layer already exists
9a0ef04f57f5: Layer already exists
d13aea24d2cb: Layer already exists
2b3eec357807: Layer already exists
2dadbc36c170: Layer already exists
8a70d251b653: Layer already exists
0047b729188a: digest: sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c size: 1570
++ docker inspect '--format={{index .RepoDigests 1}}' mcelep/nginx:0047b729188a
+ NEW_IMAGE_DIGEST=mcelep/nginx@sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c
+ COSIGN_EXPERIMENTAL=1
+ cosign sign -y mcelep/nginx@sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c
Generating ephemeral keys...
Retrieving signed certificate...

        Note that there may be personally identifiable information associated with this signed artifact.
        This may include the email address associated with the account with which you authenticate.
        This information will be used for signing this artifact and will be stored in public transparency logs and cannot be removed later.
Your browser will now be opened to:
https://oauth2.sigstore.dev/auth/auth?access_type=online&client_id=sigstore&code_challenge=djbmOu2shIxHWm1hEfLUkIviVrC01MyNk6W_jZZPQt0&code_challenge_method=S256&nonce=2JjwTYdZNdewulPAaSTBAC2MRGl&redirect_uri=http%3A%2F%2Flocalhost%3A54564%2Fauth%2Fcallback&response_type=code&scope=openid+email&state=2JjwTXlmKNswREyGf0aBFoXTyoh
Successfully verified SCT...
tlog entry created with index: 10276941
Pushing signature to: index.docker.io/mcelep/nginx
+ COSIGN_EXPERIMENTAL=1
+ cosign verify mcelep/nginx@sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c

Verification for index.docker.io/mcelep/nginx@sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - Any certificates were verified against the Fulcio roots.

[{"critical":{"identity":{"docker-reference":"index.docker.io/mcelep/nginx"},"image":{"docker-manifest-digest":"sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c"},"type":"cosign container image signature"},"optional":{"1.3.6.1.4.1.57264.1.1":"https://accounts.google.com","Bundle":{"SignedEntryTimestamp":"MEYCIQCk370izIIwXhvIvHy/sEMMgJCRZFN8ll0bht1elFr23QIhAPQFrRDlNhEr/g7SCOpBhlnH6x7V/2QX7dgvgsPxao9Z","Payload":{"body":"eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiI3N2NlZTIxYjZjNzNkNmJiZjNjMmZiOTBlMGMxOTI1YmMxNjFlZTQ5NzFmMzYxYWI0MzhhOWRmNjhkOGE1ZmVjIn19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FVUNJQXJuYVRYeXZ0bVk2VjJyQ1JWWVVIbVNUdFkrUFVpZkZOa2hvT2plQWF3UUFpRUFtU3NZK1J3dUdUb1UvUkF5ZHE2SVFLUVlPZWJXMDc4Zm1nNjVLcE91bndrPSIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2sxSlNVTnVWRU5EUVdsVFowRjNTVUpCWjBsVlpIQkxibGcyWjNOUmJrNVBjRUZpWTFRd2JIUkdNRzlLT0c1WmQwTm5XVWxMYjFwSmVtb3dSVUYzVFhjS1RucEZWazFDVFVkQk1WVkZRMmhOVFdNeWJHNWpNMUoyWTIxVmRWcEhWakpOVWpSM1NFRlpSRlpSVVVSRmVGWjZZVmRrZW1SSE9YbGFVekZ3WW01U2JBcGpiVEZzV2tkc2FHUkhWWGRJYUdOT1RXcEplRTFxVFhkTlZFRXhUV3BSTlZkb1kwNU5ha2w0VFdwTmQwMVVSWGROYWxFMVYycEJRVTFHYTNkRmQxbElDa3R2V2tsNmFqQkRRVkZaU1V0dldrbDZhakJFUVZGalJGRm5RVVZ1Y2toV1NWSnFUa1prUmpaSVF5OW9VVTlPZUVWSlVYZFpiVzlCZVRRelpVaFRVM1VLU1dOUlVtSmhUWFZYYVhsSlkwaExlVUpxZDFGMlUzWlJjM0ZDVG0xQ2FXZE5kbTE0WW1ZNFJtWlFaWGRvYVhWTGMzRlBRMEZWVFhkblowVXZUVUUwUndwQk1WVmtSSGRGUWk5M1VVVkJkMGxJWjBSQlZFSm5UbFpJVTFWRlJFUkJTMEpuWjNKQ1owVkdRbEZqUkVGNlFXUkNaMDVXU0ZFMFJVWm5VVlYyUVRWSUNuVlBVR1ZpU0c1T1ZXVXhUakpWTkhOdFVHUlhTMHM0ZDBoM1dVUldVakJxUWtKbmQwWnZRVlV6T1ZCd2VqRlphMFZhWWpWeFRtcHdTMFpYYVhocE5Ga0tXa1E0ZDBsUldVUldVakJTUVZGSUwwSkNZM2RHV1VWVVlsZE9iR0pIVm5kTWJWSnNVVWRrZEZsWGJITk1iVTUyWWxSQmNFSm5iM0pDWjBWRlFWbFBMd3BOUVVWQ1FrSjBiMlJJVW5kamVtOTJUREpHYWxreU9URmlibEo2VEcxa2RtSXlaSE5hVXpWcVlqSXdkMmRaYTBkRGFYTkhRVkZSUWpGdWEwTkNRVWxGQ21WM1VqVkJTR05CWkZGRVpGQlVRbkY0YzJOU1RXMU5Xa2hvZVZwYWVtTkRiMnR3WlhWT05EaHlaaXRJYVc1TFFVeDViblZxWjBGQlFWbFdhWEZpZWk4S1FVRkJSVUYzUWtkTlJWRkRTVWh2VTJwS1ZFMXFXblJqUTJ3NVRtMWpZVFowTWxWWldGQldVbTlGVEM4eEsyUkhVVEJyT1dWMFluSkJhVUZqVVhRelRBcHBjMDE2YXpkd2JVWlROelJaTUc1aVoydFRLMlV5ZWs1RWFVZEtaM0pXTW5WRlRITjBSRUZMUW1kbmNXaHJhazlRVVZGRVFYZE9ia0ZFUW10QmFrRlNDbGd6ZW1SWGJtaEdWMjVwY1hSRk5sRnZVRWhJUWxocFJWVkJWVkl2SzBKbWFtSXZiWE4xZHpCUFdFVkRlV0Z0TWl0WVluVlFUMFl3VUV0RFZsRnFNRU1LVFVGVVJFMUlXbU15YlhscmJEUkZhVTl6VGxSTFdHOVJTM0EyVEdod1QwRk5LMWxuUlRSalRVWm1hV054Wmk5SWNEaEdiRk01Um5SWVV6QjVhM0oyTndwRVFUMDlDaTB0TFMwdFJVNUVJRU5GVWxSSlJrbERRVlJGTFMwdExTMEsifX19fQ==","integratedTime":1672397572,"logIndex":10132644,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d"}},"Issuer":"https://accounts.google.com","Subject":"mcelep.de@gmail.com"}},{"critical":{"identity":{"docker-reference":"index.docker.io/mcelep/nginx"},"image":{"docker-manifest-digest":"sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c"},"type":"cosign container image signature"},"optional":{"1.3.6.1.4.1.57264.1.1":"https://accounts.google.com","Bundle":{"SignedEntryTimestamp":"MEUCIC1x6cTJw2a/dCXU+H4TIHcmtyKlkBbfb8vIoc/FMQOiAiEAo901AboBv208u2tPNu4kfFp9P1GyQH6E9BxmbW9xhUI=","Payload":{"body":"eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiI3N2NlZTIxYjZjNzNkNmJiZjNjMmZiOTBlMGMxOTI1YmMxNjFlZTQ5NzFmMzYxYWI0MzhhOWRmNjhkOGE1ZmVjIn19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FVUNJUUR3NEJRRzBkV0ZMMGtrVlkySThvN1FnV0pKZDJnMmtkV05xRHZGZkxYQ3FRSWdlc092Zit6WXFod3N6by9kY3VOckdZSDB0MHpiQ2lQYkoxL2ZMV0tvSlJnPSIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2sxSlNVTnZSRU5EUVdsWFowRjNTVUpCWjBsVlkyWm9MMU1yVDBsc2FUYzJWamhYUWt0bU5VMVpSM0UzVm5wVmQwTm5XVWxMYjFwSmVtb3dSVUYzVFhjS1RucEZWazFDVFVkQk1WVkZRMmhOVFdNeWJHNWpNMUoyWTIxVmRWcEhWakpOVWpSM1NFRlpSRlpSVVVSRmVGWjZZVmRrZW1SSE9YbGFVekZ3WW01U2JBcGpiVEZzV2tkc2FHUkhWWGRJYUdOT1RXcE5kMDFVUVhoTlZFRjNUa1JKTTFkb1kwNU5hazEzVFZSQmVFMVVRWGhPUkVrelYycEJRVTFHYTNkRmQxbElDa3R2V2tsNmFqQkRRVkZaU1V0dldrbDZhakJFUVZGalJGRm5RVVZ6YTFCWFdHY3ZOWGgyYTFKSVNHWmpTVWxDVjA1S2NVcHVUVVZGVm5CSVQzbEpkSEVLVWxnd2FXWm9abk5YYzFsalFuSm5NM04wS3pFMVdGbExWREJVTVUxalpuaHZNRWRtTlRGck5ISlNaRGhXYzJGWGFtRlBRMEZWVVhkblowWkJUVUUwUndwQk1WVmtSSGRGUWk5M1VVVkJkMGxJWjBSQlZFSm5UbFpJVTFWRlJFUkJTMEpuWjNKQ1owVkdRbEZqUkVGNlFXUkNaMDVXU0ZFMFJVWm5VVlZEUVdkbkNsVjFhVTVzYm1wMk9XZHhiMlk1V1daQ1EwdHZjRGRCZDBoM1dVUldVakJxUWtKbmQwWnZRVlV6T1ZCd2VqRlphMFZhWWpWeFRtcHdTMFpYYVhocE5Ga0tXa1E0ZDBsUldVUldVakJTUVZGSUwwSkNZM2RHV1VWVVlsZE9iR0pIVm5kTWJWSnNVVWRrZEZsWGJITk1iVTUyWWxSQmNFSm5iM0pDWjBWRlFWbFBMd3BOUVVWQ1FrSjBiMlJJVW5kamVtOTJUREpHYWxreU9URmlibEo2VEcxa2RtSXlaSE5hVXpWcVlqSXdkMmRaYjBkRGFYTkhRVkZSUWpGdWEwTkNRVWxGQ21aQlVqWkJTR2RCWkdkRVpGQlVRbkY0YzJOU1RXMU5Xa2hvZVZwYWVtTkRiMnR3WlhWT05EaHlaaXRJYVc1TFFVeDViblZxWjBGQlFWbFdjM2xwTlhBS1FVRkJSVUYzUWtoTlJWVkRTVWRvWkd4a09VbGxObEUzVDBaMFprNWtXVmQyTm0xWVlqbHdWRlpYU1U5VVIxbGlWazQyUm1ScFZVOUJhVVZCTDNoUmJRbzRZWFV4TW5nMU5uRXhhSFpKVFV4SFlVTklWV2xuU1dGbFZqaG5kbkozTTBkV1ltOW5LMmQzUTJkWlNVdHZXa2w2YWpCRlFYZE5SR0ZSUVhkYVowbDRDa0ZPVFhRclZFNXpNMjR6WW5oamRuTllWR3N4VERBNFNFeFFZVEJYYmpVNGIySjNjekZVTkRkRlUxTjJUVWxxUlhsYWFYbDZTV1ZVU3poTGQwOURWVzBLV1VGSmVFRlFaRXBWVTJ4T2N6UjJWWEJtZEVVMWRrdzVTMXBYSzFGdFFqVlJWRkEwVjFSSVJEZ3lkRmRHTVRkQ2JWUkNRMmw0TjBWbVNXRnViV1pSVndwb1NYQTFSM2M5UFFvdExTMHRMVVZPUkNCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2c9PSJ9fX19","integratedTime":1672567470,"logIndex":10251668,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d"}},"Issuer":"https://accounts.google.com","Subject":"mcelep.de@gmail.com"}},{"critical":{"identity":{"docker-reference":"index.docker.io/mcelep/nginx"},"image":{"docker-manifest-digest":"sha256:9a821cadb1b13cb782ec66445325045b2213459008a41c72d8d87cde94b33c8c"},"type":"cosign container image signature"},"optional":{"1.3.6.1.4.1.57264.1.1":"https://accounts.google.com","Bundle":{"SignedEntryTimestamp":"MEYCIQD9+5JaiJ+Uefak+AL6zIgU4jW0T54ZHXH9xeBzpupTvAIhAJTUez7iVVslv82DwpsnCTfmEPClFHnn4BnJfHk6Z5s4","Payload":{"body":"eyJhcGlWZXJzaW9uIjoiMC4wLjEiLCJraW5kIjoiaGFzaGVkcmVrb3JkIiwic3BlYyI6eyJkYXRhIjp7Imhhc2giOnsiYWxnb3JpdGhtIjoic2hhMjU2IiwidmFsdWUiOiI3N2NlZTIxYjZjNzNkNmJiZjNjMmZiOTBlMGMxOTI1YmMxNjFlZTQ5NzFmMzYxYWI0MzhhOWRmNjhkOGE1ZmVjIn19LCJzaWduYXR1cmUiOnsiY29udGVudCI6Ik1FUUNJSDN1N1RJSUwwUk1DMXZlZ2Fjdlh1dXZsT3graXUxTlp3REdEQzBnZ1AraEFpQXNSZ3lUVU1HZG00WmxNY254cDU5MURkaEtBUDN4OW9oU0lVVmFiMXZqalE9PSIsInB1YmxpY0tleSI6eyJjb250ZW50IjoiTFMwdExTMUNSVWRKVGlCRFJWSlVTVVpKUTBGVVJTMHRMUzB0Q2sxSlNVTnVWRU5EUVdsUFowRjNTVUpCWjBsVllrdDJObkI0VUhKeVdYSnNiRVZvVm05SFdqbHJlVFJwY1VNMGQwTm5XVWxMYjFwSmVtb3dSVUYzVFhjS1RucEZWazFDVFVkQk1WVkZRMmhOVFdNeWJHNWpNMUoyWTIxVmRWcEhWakpOVWpSM1NFRlpSRlpSVVVSRmVGWjZZVmRrZW1SSE9YbGFVekZ3WW01U2JBcGpiVEZzV2tkc2FHUkhWWGRJYUdOT1RXcE5kMDFVUVhoTmFrRjVUbXBWTWxkb1kwNU5hazEzVFZSQmVFMXFRWHBPYWxVeVYycEJRVTFHYTNkRmQxbElDa3R2V2tsNmFqQkRRVkZaU1V0dldrbDZhakJFUVZGalJGRm5RVVZMTHpkQ1VIQkxOR1ZzZVU1WVlsaDVVbEJrUnpRdlVTOVlTMWhUY0U0NVRHVTFhWElLTldjdmN5OU5RMk5oY25GU1IwMHZRbkJZZGtaSlpsVk9lbFJpZFVkMk1pOTRkRWhWYm1oQ1ZVZDZLMkkwUjFKUGVrdFBRMEZWU1hkblowVXJUVUUwUndwQk1WVmtSSGRGUWk5M1VVVkJkMGxJWjBSQlZFSm5UbFpJVTFWRlJFUkJTMEpuWjNKQ1owVkdRbEZqUkVGNlFXUkNaMDVXU0ZFMFJVWm5VVlZCT1dWRkNrZG5ORWd3UlhkbFIwVXJUVWhGYVRKNVYxQkxaWGQzZDBoM1dVUldVakJxUWtKbmQwWnZRVlV6T1ZCd2VqRlphMFZhWWpWeFRtcHdTMFpYYVhocE5Ga0tXa1E0ZDBsUldVUldVakJTUVZGSUwwSkNZM2RHV1VWVVlsZE9iR0pIVm5kTWJWSnNVVWRrZEZsWGJITk1iVTUyWWxSQmNFSm5iM0pDWjBWRlFWbFBMd3BOUVVWQ1FrSjBiMlJJVW5kamVtOTJUREpHYWxreU9URmlibEo2VEcxa2RtSXlaSE5hVXpWcVlqSXdkMmRaWjBkRGFYTkhRVkZSUWpGdWEwTkNRVWxGQ21WblVqUkJTRmxCWkVGRVpGQlVRbkY0YzJOU1RXMU5Xa2hvZVZwYWVtTkRiMnR3WlhWT05EaHlaaXRJYVc1TFFVeDViblZxWjBGQlFWbFdka0pDV1ZrS1FVRkJSVUYzUWtaTlJVMURTVUpuU21aR2IyMXRiSFIxYWtRemFGWmhiRUZXZFVkaWQwdHNUWGxsVDBnd2JXNUROMXBOTWsxVloyOUJhRGhIU1d4TlNBcFdXbklyYTFkTWNrUnNLMnc0ZHpoVlZHa3dTWFp3YlZkSGRHa3hjWEpSV1ZKNVNsVk5RVzlIUTBOeFIxTk5ORGxDUVUxRVFUSm5RVTFIVlVOTlVVTmhDakY0YkVZM1NFYzBiVXBsU0ZsaWJIUjFkVTVMY0RSa2JtZHlWV0psVWxWUmVuRXpiVVJaTUVkRlNHUjRNV012YWpobmNVcGxiRGRvZFU5Wk1FUlZNRU1LVFVGcGN6VlNSSEF3VmtOUVZEUTNTRzVFY1RWQ2NtVTNkMnd5VGxGcGJFRTNTbWg1T0cxSlFqbEZlR2RaT1ZKaVdYRnRWelp6TURVM01WZE5lVlI0UXdwMVFUMDlDaTB0TFMwdFJVNUVJRU5GVWxSSlJrbERRVlJGTFMwdExTMEsifX19fQ==","integratedTime":1672604819,"logIndex":10276941,"logID":"c0d23d6ad406973f9559f3ba2d1ca01f84147d8ffc5b8445c224f98b9591801d"}},"Issuer":"https://accounts.google.com","Subject":"mcelep.de@gmail.com"}}]
```

A couple of points to pay attention regarding the output above:
- The field called ```Subject``` denotes the identity used for signing the container image.
- The field called ```Issuer``` denotes which Identity provider is used to authenticate with Fulcio. In our example it happens to be "https://accounts.google.com".

- The image coordinates together with Subject and Issuer data togeter gives all the context required for verifying the owner of a given container image.

- There are other ways to assign ownership to images.

    - Container image metadata/labels 

    - If namespaces are used for segregation of apps/teams/domains, then namespaces could be used for finding ownership.

    - Having a notary mechanism and verifying the identity via the notary mechanism is the safest.


### Cosign-gatekeeper-provider:

Gatekeeper runs on OPA. 
 , [ExternalData feature](https://open-policy-agent.github.io/gatekeeper/website/docs/externaldata) provides an easy way to call external functions(things that might be difficult to do in Rego and built-ins are missing)
