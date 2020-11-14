# Enforcing policies in Kubernetes

Kubernetes(K8S) has established itself as the go-to platform for container based workloads and many companies have either already started or going to start soon migrating their workloads onto Kubernetes.

Kubernetes offers so many capabilities out of box, and it exposes many infrastructure related controls to developers. Developers, who are not used to dealing with those infrastructure level concerns, might struggle to grasp all those new controls and abstractions which are not at their disposal. Trainings(such as ones on [here](https://kube.academy/)) will certainly help to bring developers up to speed with K8S but if we want to really ensure that our applications fulfill all the requirements (such as availability, security, etc.) we want them fulfill, we better do a bit more than just publishing best practices in an intranet wiki page and expect developers to adhere to those best-practices religiously.

But how can you enforce your company's K8S best practices? How can you create 'policies' that covers security and high availability concerns? How can you govern the behavior of a software service?

*All the relevant files can be found in [this git repo](https://github.com/mcelep/blog/tree/master/opa-policies/conformance-testing).*
## Enter Open Policy Agent(OPA)

[Open Policy Agent(OPA)](https://www.openpolicyagent.org/) is a Cloud Native Computing Foundation project and it aims at solving 'policy enforcement' problem across the Cloud-Native stack(Kubernetes, Docker, Envoy, Terraform,etc.).

OPA comes with a language called [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) to author policies efficiently and other than Rego, there are a number of tools & components in OPA to make use of policies easier & efficient.

## Different options to enform policies & run policy checks

We see several options to enforce policies and inform users about conformance to policies.

### Admission Controllers

The ultimate level of enforcing policies happens directly on a K8S cluster. That is, one can hook into [Admission Controller](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) mechanism of Kubernetes to reject K8S Resource modifications that are not allowed by policies.

OPA comes with a component called [Gatekeeper](https://www.openpolicyagent.org/docs/latest/kubernetes-introduction/) This components is an Admission Controller, and it aims at managing and enforcing policies easily on K8S clusters.

OPA Gatekeeper can (as of 30.10.2020) either deny a admission request (optionally providing some explanation about why an admission was refused) or accept an admission request with no explanation. At the moment there's not a way to accept an admission but provide a **warning** back to user(an example use case could look like: a request might be admitted at that point in time but will not be admitted any more at a later date due to upcoming policy updates). There is [an open issue](https://github.com/open-policy-agent/gatekeeper/issues/701) on Github that's for adding a *warn* action.

Using *Admission Controllers* brings a binary approach to accepting changes on API resources on a K8S cluster. This helps to make sure no non-policy-conformal workload runs on the platform but it misses to differentiate between recommended vs. obligatory practices. This is where a 'report card' based approach comes handy.

### Visualization / Report cards

Creating a 'conformance' report for workloads running on K8S clusters is a good way to increase awareness amongst application teams about how their applications fulfill the requirements. In our professional services engagements which includes application  commissioning into production, we typically prepare a custom "Production Readiness Checklist" document that includes both obligatory as well as recommended items. There might be certain points in such a list that pretty much universal but some are specific to customers due to needs such as high availability, performance or regulatory requirements (e.g. Financial Service regulations).

Creating a report card that is generated programmatically upon demand (or periodically) and showing this report to users in a visually pleasing way could be very helpful in many large organizations that has many K8S applications.

[Polaris OS project](https://github.com/FairwindsOps/polaris) comes with such a feature out of the box, see the image below:

![report]([dashboard-screenshot.png](https://github.com/mcelep/blog/blob/master/opa-policies/conformance-testing/dashboard-screenshot.png?raw=true))

When creating such a report, displaying not only failed policy checks but also providing some explanations about why such a policy rule was created and how to fix that issue (typically by providing a link to an internal wiki page), will be much appreciated by readers of the report.

### CI/CD

Another point/stage where you could test K8S resources against policies is CI/CD pipelines and to be more precise it's the CD(Continues Delivery) part of CI/CD. It should be quite east to add a 'policy check step' to deployment pipelines in most of the CI/CD solutions out there. And the benefit of running policy conformance checks as part of a deployment pipeline is that, conformance check results can include not only **Ok**s or **Nok**s but also warnings. A CI/CD system might also allow you to save reports  Moreover, if K8S clusters(especially production clusters) can only be accessed via CD pipelines (and not directly by users as we see in many enterprises) and if you can enforce such a 'policy check step' in all deployment pipelines, you end up with a solution that is similar to an 'Admission Controller'.

## OPA policies in practice

In this section, we will write a couple of policies to get a better understanding about what the process feels like.

### Rego

[Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) is a DSL that is not that difficult to get into but that said it takes some getting used to.

[This](https://academy.styra.com/courses/opa-rego) free course can be helpful if you want to start with a self-paced video based training.

Best way to learn it is use it and while learning Rego, practicing in an interactive shell can be very helpful, here are some options:

- [Playground](https://play.openpolicyagent.org/) comes in handy for testing out rego expressions online.

- [REPL environment for rego](https://github.com/fugue/fregot) can be used if you want to have a local environment to test things out in rego.

If you use Visual Studio Code as your editor, you might also find [this](https://marketplace.visualstudio.com/items?itemName=tsandall.opa) plugin helpful when developing Rego policies.

### Conftest

[Conftest](https://www.conftest.dev/) is a utility to help writing/maintaining [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) based policies against files(structured data).

We will be using conftest to run unit tests. Both OPA cli as well as conftest has means to run unit tests. As the policy files we create become more complex, the unit tests will give us some peace of mind. When writing those unit tests, we should pay attention to testing both positive and negative cases. For example if we're testing a rule that should 'warn' us, we need to write unit tests that would trigger a warn but also one that is the 'happy path' as in there's no warning triggered.

The policies that we aim to write cover the following concerns for deployments:

- A deployment should have at least 2 replicas (for high availability)
- Containers in a deployment should have a liveness probe
- Containers is a deployment should have a readiness probe
- Containers in a deployment should define resources for both *limits* and *requests*
- Deployment should have anti-affinity rules setup

These concerns above are meant to just provide a basic set of best practices for running apps in production on a K8S cluster. They are not meant to be complete and they are just used as input for experimenting with Rego policies.

Under *policy* folder there are policy files and their corresponding unit test files(with suffix: *_test*).

Conftest provides 3 levels for rules: *deny, violation, and warn*. In our example policy file for deployments(Deployment.rego), we decided to use *warn* level and also included a descriptive name in the part that follows *warn_*. for example ```warn_at_least_2_replicas[msg]```. The variable which is called *msg* in this example, is used as an output variable. In our rules, the value of *msg* is static, it does not depend on data this rule receives but you might want to make the value of *msg* dynamic, to provide explanation/hints about what part of input data fails to comply with the rule.

There is an accompanying unit test *deployment_test.rego* provided in the same folder as the policy file *deployment.rego*. Data used in unit tests is also embedded into the unit test file. For example, for tests which target rule *warn_at_least_2_replicas* , there are 2 variables called *deployment_1_replica* and *deployment_2_replica* which contain the relevant data. Embedding large amount test data into the unit test file itself is not an ideal solution though, that part should be improved. In the *helpers* there is a python script which was written to convert yaml into json while removing empty elements as they proved to be problematic for the rego compiler.

#### Running unit tests

Conftest comes with unit testing capability to check sanity of the rules and this proves to be a very useful feature. Rego, although it's not a very difficult language to grasp, takes some getting used to so writing unit tests for both happy & unhappy paths for each rule will contribute to improved quality assurance. 

Unit tests can be executed with the following command:
```bash
#Make sure you are in the folder that includes the folder policy
conftest verify --trace
```


#### Executing policy checks

The policy files can be tested against static files:
```bash
#Make sure you are in folder conftest
cat helpers/deployment.yaml | conftest test -
```

 or live Kubernetes resources:
```bash
k get deployments nginx -n test -o yaml | conftest test -
+ kubectl get deployments nginx -n test -o yaml
WARN - There must be a readinessProbe for each container
WARN - There must be at least 2 replicas for each deployment
WARN - Pod affinity rules should have been set

8 tests, 5 passed, 3 warnings, 0 failures, 0 exceptions
```
