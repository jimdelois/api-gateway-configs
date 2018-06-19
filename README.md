# Kong

## AWS

### Cloudformation Setup

Create the database independently, as it is extremely time/resource intensive which may
impede any modifications to the balance of the stack in the future:

```
aws cloudformation create-stack --stack-name kong-database --template-body file://.aws/cloudformation/kong.database.stack.yml --parameters file://.aws/cloudformation/kong.database.stack.parameters.json
```

Now, create the rest of the stack:
```
aws cloudformation create-change-set --stack-name kong --change-set-type CREATE --change-set-name InitialRevision --template-body file://.aws/cloudformation/kong.stack.yml --parameters file://.aws/cloudformation/kong.stack.parameters.json
```

## Local Setup

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
