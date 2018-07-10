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

To perform DB migrations for the Kong backing store (whether installing a fresh schema or updating an existing one), perform the following:

```
aws ecs run-task --cluster kong --task-definition kongmigration --count 1
```

And now the same for Konga:

```
aws ecs run-task --cluster kong --task-definition kongamigration --count 1
```

Extract the Task ARN from that command and copy it.  This particular migration is performed by running the Konga application in `dev` mode - as such, it will not actually terminate itself and it must be stopped manually:

```
TASK_ARN=
aws ecs stop-task --cluster kong --task $TASK_ARN --reason "Migrations Completed"
```


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
