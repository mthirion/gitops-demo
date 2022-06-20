
#K8_SRC_FILE=/development/workspace/internal/integration/quarkus/quarkus2-rest-server/target/kubernetes/openshift.json

JQ_K8_SRC_HOME=$JQ_SOURCE_DIR/target/kubernetes/openshift.json
JQ_TARGET_DIR=$JQ_SOURCE_DIR/target/jq-generated

if [[ ! -f $JQ_K8_SRC_HOME ]]
then
	echo "Cannot find openshift.json as $JQ_K8_SRC_HOME"
	exit 1
fi

mkdir -p $JQ_TARGET_DIR
rm -rf $JQ_TARGET_DIR/*.yaml
cat $JQ_K8_SRC_HOME | jq -n -c inputs | while read -r line
do 
	echo $line; echo "" ; echo ""  
	
	# Generate file name
	name=`echo $line | jq '.metadata.name'| sed 's/"//g' `
	kind=`echo $line | jq '.kind' | sed 's/"//g' `
	echo $line > $JQ_TARGET_DIR/$kind-$name.json
done

echo "generated"
ls $JQ_TARGET_DIR

exit 0
