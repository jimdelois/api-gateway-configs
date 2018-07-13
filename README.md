# Kong

## Setup / Deployment

The Kong API Gateway and the associated Konga Admin UI each need their own backing store and their respective schemas correctly installed. Both applications support multiple stores, so to keep things simple and consolidated, we choose the only overlap: Postgres.

Kong and Konga both provide their own "migrations" management mechanism so an initial setup in either AWS or on one's local will require a couple of extra steps to ensure the database is up-to-date.

### AWS Installation (CloudFormation)

#### Database

Create the database independently, as it is extremely time/resource intensive which may
impede any modifications to the balance of the stack in the future:

```
aws cloudformation create-stack --stack-name kong-database --template-body file://.aws/cloudformation/kong.database.stack.yml --parameters file://.aws/cloudformation/kong.database.stack.parameters.json
```

#### Application

Using a reviewable change set, create the rest of the stack which installs and starts the entire application:

```
aws cloudformation create-change-set --stack-name kong --change-set-type CREATE --change-set-name InitialRevision --template-body file://.aws/cloudformation/kong.stack.yml --parameters file://.aws/cloudformation/kong.stack.parameters.json
```

Review the requested change set:

```
aws cloudformation describe-change-set --change-set-name "InitialRevision" --stack-name kong
```

Extract the ARN and execute the change set:

```
CHANGESET_ARN=
aws cloudformation execute-change-set --change-set-name $CHANGESET_ARN
```

**NOTE**: It's possible that the application will thrash a bit if the migrations haven't been run, as it will detect invalid schemas and shut down. Run the migrations, below, and monitor for eventual stability.

#### Schema Migrations

Whether installing a fresh schema or updating an existing one, DB migrations will need to be performed for the the Kong and Konga backing stores.

Depending on the configuration, it may be desirable to scale the EC2 group first, ensuring that there is capacity in the cluster for deploying and executing these tasks.

##### Extracting the AutoScaling Group Name

We haven't named our AutoScaling Group so as to avoid resource replacement should the need arise to adjust it.  For this reason, we must to extract the name of the group, which has been dynamically generated.  We can list all the groups and pluck out then one we need (which should be obvious):

```
aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[].AutoScalingGroupName"
```

Or, if we want the lengthier version of pulling out exactly the correct one:

```
aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[?Tags[?Key == 'aws:cloudformation:logical-id' && contains(Value, 'KongECSInstanceAutoScalingGroup')]].AutoScalingGroupName"
```

##### Scale the Group Up

```
$GROUP_NAME=
aws autoscaling set-desired-capacity --auto-scaling-group-name $GROUP_NAME --desired-capacity 2 --honor-cooldown
```

Check in on these instances with:

```
aws ecs list-container-instances --cluster Kong
```

##### Perform the Migrations

Execute the migrations by performing the following:

```
# Kong
aws ecs run-task --cluster kong --task-definition kongmigration --count 1

# Konga
aws ecs run-task --cluster kong --task-definition kongamigration --count 1
```

Extract the Task ARN from that last command and copy it.  This particular migration is performed by running the Konga application in `dev` mode - as such, it will not actually terminate itself and it must be stopped manually:

```
TASK_ARN=
aws ecs stop-task --cluster kong --task $TASK_ARN --reason "Migrations Completed"
```

##### Scale the Group Back Down

```
$GROUP_NAME=
aws autoscaling set-desired-capacity --auto-scaling-group-name $GROUP_NAME --desired-capacity 1 --honor-cooldown
```

#### Install Auto-Scaling Policies (Optional)

Implementing Auto-Scaling in AWS is done by attaching scaling policies to existing resources.  This one-way dependency of the former on the latter allows us to completely decouple the two. Not only does this make Auto-Scaling entirely optional, it also yields smaller and more manageable/targeted CloudFormation Stack files.

This could further be broken down into EC2 Instance Auto-Scaling and ECS Service Auto-Scaling. For now, both configurations are managed in the same Stack.

To install Auto-Scaling Policies:

```
aws cloudformation create-stack --stack-name kong-autoscaling --template-body file://.aws/cloudformation/kong.scaling.stack.yml
```

**TODO:** The Auto-Scaling stack can (and should) be made highly configurable and parameterized.

#### Install Dashboards (Optional)

CloudFormation can manage CloudWatch Dashboards, as well. To keep things reasonably organized and manageable, we separate these into a dedicated stack, as well.  To install:

```
aws cloudformation create-stack --stack-name kong-dashboards --template-body file://.aws/cloudformation/kong.dashboards.stack.yml
```

**TODO:** Do.

#### BONUS: CI/CD Pipeline Auto-Configuration of the API Gateway

As can be seen in the Stack configs, the Admin API of Kong is tucked away and protected from public access, allowing ingress only from the Konga UI service (which is auth protected by default). However, it is possible to configure the Admin API to be exposed through Kong itself using a [loopback configuration](https://docs.gelato.io/guides/advanced-kong-integration).

Note that the Kong API Gateway makes it possible to import and export configurations.  At the point that the Admin API is exposed (and protected with by tokens, etc), any automated process may import configurations, thus making it possible for a CI/CD pipeline for an actual API application to self-register.  Further, this allows for the storage of API Gateway configuration as code, local to the API's repository.  Alternatively, normal HTTP requests may be sent to the Admin API for configuration, as well.

While this is extremely powerful, the strategies and options for it are beyond the scope of this documentation.

### Running Locally

The following will start the Postgres Database service, and then fire up an instance of the Kong
image, within which a database migration script will be invoked. This supplies the Kong Gateway
with the schema it needs to operate.

```
docker-compose up kong-migrate
```

Similarly, the Konga UI app needs a backing schema, as well.  To invoke this, ensure that the `konga` stack definition includes `NODE_ENV: dev`, and issue another:

```
docker-compose up konga
```

This process will need to be terminated (`^C`) when it appears that it is complete.

Finally, restore `NODE_ENV: production` and run the app with:

```
docker-compose up -d konga
```

#### Reverse Proxy

Note that the `docker-compose.yml` file is prepared with a few environment variables intended to be used with the [NGinx Proxy project](https://github.com/jwilder/nginx-proxy). With a working knowledge of that toolset, running also on the bridged network, it becomes trivial to augment the local gateway with SSL and domain names.  

SSL may be terminated at the NGinx Proxy, and a domain name may also be associated with the Konga Admin UI. Note that, for every API that is to be used behind Kong, there will need to be a `VIRTUAL_HOST` domain created in the environment config pointing to the Kong service. As every person's usage of Kong and DNS will be different, it is recommended to extract these configurations to a local `docker-compose.override.yml` which is ignored from this repository. An example file may look like:

```
version: '2.2'

services:
  kong:
    environment:
      VIRTUAL_HOST: .my-api.local.lan,.my-other-api.local.lan,.etc-api.local.lan
  konga:
    environment:
      VIRTUAL_HOST: .konga-ui.local.lan
```
Note also that the NGinx Proxy service could also be defined within this file if it is desired to be one-to-one with running Kong.

At this point, near-production configurations of API applications and the gateway may be obtained on the local environment.
