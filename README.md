# Kong

## AWS

### Cloudformation Setup
```
aws cloudformation create-change-set --stack-name kong --change-set-type CREATE --change-set-name InitialRevision --template-body file://.aws/cloudformation/kong.stack.yml --parameters file://.aws/cloudformation/kong.stack.parameters.json
```
