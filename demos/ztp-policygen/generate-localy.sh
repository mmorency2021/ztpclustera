#!/bin/bash
 
img=quay.io/redhat_emp1/ztp-site-generator:latest
#img=quay.io/imiller/ztp-site-generator:latest
 
src_dir=${1:-generated}
 
run_policyGen(){
    src=$(readlink -f ${1:-no_source_given})
    dst=$(readlink -f ${2:-no_dest_given})
    podman pull $img
    podman run -it --user=$(id -u):$(id -g) \
           --userns=keep-id \
           -v $src:/mnt/templates:Z \
           -v $dst:/mnt/out:Z \
           $img \
           /usr/src/hook/ztp/ztp-policy-generator/kustomize/plugin/policyGenerator/v1/policygenerator/PolicyGenerator \
           "" \
           /mnt/templates/ \
           /usr/src/hook/ztp/source-crs/ \
           /mnt/out/ \
           false
}
 
 
echo "Generating policy wrapped"
mkdir -p out
run_policyGen ./${src_dir} ./out
 
#echo "Generating reference"
#mkdir out_ref
#mkdir ${src_dir}_ref
#for fil in ${src_dir}/* ; do
#    cat $fil | yq eval '.spec.sourceFiles[] |= .policyName=""' - > ${src_dir}_ref/$(basename $fil)
#    #cat $fil | egrep -v policyName > ${src_dir}_ref/$(basename $fil)
#done
# 
#run_policyGen ./${src_dir}_ref ./out_ref
