REGION=us-east-1
NAMED_PROFILE=arch
DIR=starter
KEY_PAIR=keypair-us-east1
S3_STACK_NAME=c3-s3
# S3_STACK_TEMPLATE=${DIR}/${S3_STACK_NAME}.yml
S3_STACK_TEMPLATE=${DIR}/c3-s3_solution.yml
VPC_STACK_NAME=c3-vpc
VPC_STACK_TEMPLATE=${DIR}/${VPC_STACK_NAME}.yml
APP_STACK_NAME=c3-app
# APP_STACK_TEMPLATE=${DIR}/${APP_STACK_NAME}.yml
APP_STACK_TEMPLATE=${DIR}/c3-app_solution.yml

setup:
	@echo ">>> Setting up region: ${REGION} for profile: ${NAMED_PROFILE}"
	aws configure set region ${REGION} --profile ${NAMED_PROFILE}

lint:
	-cfn-lint ${DIR}/*.yml
	-regula run ${DIR}/*.yml

deploy: setup 
	@echo ">>> Deploying S3 buckets..."
	aws cloudformation deploy --stack-name ${S3_STACK_NAME} --template-file ${S3_STACK_TEMPLATE}
	@echo
	@echo ">>> Deploying network..."
	aws cloudformation deploy --stack-name ${VPC_STACK_NAME} --template-file ${VPC_STACK_TEMPLATE}
	@echo
	@echo ">>> Deploying app..."
	aws cloudformation deploy --stack-name ${APP_STACK_NAME} --template-file ${APP_STACK_TEMPLATE} \
	--parameter-overrides KeyPair=${KEY_PAIR} --capabilities CAPABILITY_IAM
	@echo
	@echo ">>> Uploading recipes to S3 buckets..."
	aws s3 cp ${DIR}/free_recipe.txt s3://`aws cloudformation describe-stacks --stack-name ${S3_STACK_NAME} \
	--query "Stacks[0].Outputs[?OutputKey=='BucketNameRecipesFree'].OutputValue" --output text`
	aws s3 cp ${DIR}/secret_recipe.txt s3://`aws cloudformation describe-stacks --stack-name ${S3_STACK_NAME} \
	--query "Stacks[0].Outputs[?OutputKey=='BucketNameRecipesSecret'].OutputValue" --output text`

bucket-names:
	aws s3 ls | grep "cand-c3-" | cut -d" " -f3
	@echo

clean-app: setup
	@echo ">>> Deleting ${APP_STACK_NAME} stack..."
	aws cloudformation delete-stack --stack-name ${APP_STACK_NAME}

clean-vpc: setup
	@echo ">>> Deleting ${VPC_STACK_NAME} stack..."
	aws cloudformation delete-stack --stack-name ${VPC_STACK_NAME}

clean-buckets: setup
	@echo ">>> Deleting ${S3_STACK_NAME} stack..."
	-aws s3 rm s3://`aws cloudformation describe-stacks --stack-name ${S3_STACK_NAME} \
	--query "Stacks[0].Outputs[?OutputKey=='BucketNameRecipesFree'].OutputValue" --output text` --recursive
	-aws s3 rm s3://`aws cloudformation describe-stacks --stack-name ${S3_STACK_NAME} \
	--query "Stacks[0].Outputs[?OutputKey=='BucketNameRecipesSecret'].OutputValue" --output text` --recursive
	-aws s3 rm s3://`aws cloudformation describe-stacks --stack-name ${S3_STACK_NAME} \
	--query "Stacks[0].Outputs[?OutputKey=='BucketArnVPCFlowLogs'].OutputValue" --output text | cut -d":" -f6` --recursive
	aws cloudformation delete-stack --stack-name ${S3_STACK_NAME} 

# clean: clean-app clean-vpc

clean: clean-app clean-vpc clean-buckets
