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
