#!/bin/bash
#
# Author: Alexander Rydekull <rydekull@redhat.com>
# Description:
#   This is a script to ease the management of Content Views, including upload of custom content. It will update 
#   the Content Views and make sure all Composite Content Views get updated aswell.
#
# Example:
#   [root@rhs ~]# ./manage-cv.sh --cv CV-PUPPET --lifecycle Latest --org MyOrg --repo PuppetRepo --product MyProduct --upload /root/rydekull-testmodule-0.1.6.tar.gz --update-ccvs
#   Lifecycle: Latest
#   Org: MyOrg
#   Product: MyProduct
#   Repository: PuppetRepo
#   
#   Uploading file: /root/rydekull-testmodule-0.1.6.tar.gz
#   Successfully uploaded file 'rydekull-testmodule-0.1.6.tar.gz'.
#   
#   Publishing puppet module in Content View: CV-PUPPET
#   [......................................................................................................................................................................] [100%]
#   
#   Updating the following CCVs: CCV-RHEL7-PUPPET Testing
#   
#   Removes old CV version from CCV: CCV-RHEL7-PUPPET
#   Adding new CV version to CCV: CCV-RHEL7-PUPPET
#   Publish a new version for the CCV: CCV-RHEL7-PUPPET
#   [......................................................................................................................................................................] [100%]
#   
#   Promote a new version of the CCV: CCV-RHEL7-PUPPET
#   [......................................................................................................................................................................] [100%]
#   

function usage()
{
  if [ "$1" != "" ]
  then
    echo "Error: $1"
  fi
  echo "Usage: $(basename $0) <arguments>"
  echo 
  echo "Arguments:"
  sed -n '/^# Start Usage hack/,/^# End Usage hack/p' $0 | grep -e "--.*)" | grep \# | sed 's/) #/ -/g' | sort
  exit 99
}

# Start Usage hack
# Simply put, the Usage function subtracts information from the scripts while-function below
while :
do
  case "$1" in
    --clean) # Todo: Clean the Content Views of older versions
      usage
    ;;
    --cv) # Content View name (Label) to update
      CV="$2"
      shift 2
    ;;
    --help) 
      usage
    ;;
    --lifecycle) # Lifecycle to use for the promotion
      LIFECYCLE=$2
      shift 2
    ;;
    --product) # Product name
      PRODUCT=$2
      shift 2
    ;;
    --org) # Organization name
      ORG=$2
      shift 2
    ;;
    --repo) # Repository name
      REPO=$2
      shift 2
    ;;
    --save-defaults) # Todo: Save settings as defaults
      usage
    ;;
    --update-ccvs) # Update all Composite Content Views
      UPDATE_CCVS="true"
      shift
    ;;
    --upload) # Upload a RPM or Puppet module
      UPLOAD_FILE=$2
      if [ ! -f "$UPLOAD_FILE" ]
      then
        usage "Cannot find the file: $UPLOAD_FILE"
      fi
      shift 2
    ;;
    --debug) # Debug mode for some further information
      DEBUG="true"
      shift
    ;;
    --)
      shift
      break
    ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      echo
      usage
    ;;
    *)
      break
    ;;
  esac
done
# End Usage hack

# Just check so that we have everything in place
[ "$LIFECYCLE" = "" ] && usage "No lifecycle supplied"
[ "$ORG" = "" ] && usage "No organization supplied"
[ "$PRODUCT" = "" ] && usage "No product supplied"
[ "$REPO" = "" ] && usage "No repo supplied"
echo "Lifecycle: $LIFECYCLE"
echo "Org: $ORG"
echo "Product: $PRODUCT"
echo "Repository: $REPO"

# Find out the Lifecycle ID
LIFECYCLE_ID=$(hammer --csv lifecycle-environment list --organization-id 3 --name $LIFECYCLE | awk -F"," '$1 ~ /^[0-9]/ { print $1 }')

# If we have a upload file defined, lets deal with it
if [ "$UPLOAD_FILE" != "" ]
then
  echo
# For future versions
#  MYDIR="/root/puppet"
#  PUPPET_MODULE=$1
#  echo Raising puppet revision version by 1
#  version=$(head -10 ${MYDIR}/${PUPPET_MODULE}/metadata.json | grep version | awk '{ print $NF }' | sed -e 's/"//g' -e 's/,//g')
#  major_version=$(echo $version | cut -d. -f 1)
#  minor_version=$(echo $version | cut -d. -f 2)
#  rev_version=$(echo $version | cut -d. -f 3)
#  let rev_version=$rev_version+1
#  new_version="$major_version.$minor_version.$rev_version"
#
#  sed -i "s/$version/$new_version/" ${MYDIR}/${PUPPET_MODULE}/metadata.json
#
#  echo Building puppet module
#  puppet module build ${MYDIR}/${PUPPET_MODULE}
#  UPLOAD_FILE="${MYDIR}/${PUPPET_MODULE}/pkg/${PUPPET_MODULE}-${new_version}.tar.gz"

  echo Uploading file: ${UPLOAD_FILE}
  hammer repository upload-content --organization-label $ORG --product "${PRODUCT}" --name ${REPO} --path "${UPLOAD_FILE}"
fi

echo
PUPPET_CV_ID=$(hammer content-view list --organization-label ${ORG} | grep $CV | awk '{ print $1 }')

echo Publishing puppet module in Content View: $CV
hammer content-view publish --name $CV --organization-label $ORG

#echo hammer content-view version list --organization-label $ORG --content-view $CV
PUPPET_CV_LATEST_VERSION=$(hammer --csv content-view version list --organization-label ${ORG} --content-view $CV | head -2 | tail -1 | cut -d, -f1)

# If we will not update the CCVs we need to promote the CV
if [ "$UPDATE_CCVS" != "true" ]
then
  echo
  # If there is no lifecycle environment, do it for all following "Library"
  if [ "$LIFECYCLE" = "" ]
  then
    FIRST_LIFECYCLE_ENV=$(hammer lifecycle-environment list --organization-label ${ORG} | awk '$NF ~ /^Library$/ { print $1 }')
    for LIFECYCLE_ENV in $FIRST_LIFECYCLE_ENV
    do
      echo Promoting content view: $CV
      hammer content-view version promote --to-lifecycle-environment-id $LIFECYCLE_ENV --organization-label $ORG --content-view-id $PUPPET_CV_ID --id $PUPPET_CV_LATEST_VERSION --version $CV
    done
  else
    echo Promoting content view: $CV
    hammer content-view version promote --to-lifecycle-environment $LIFECYCLE --organization-label $ORG --content-view-id $PUPPET_CV_ID --id $PUPPET_CV_LATEST_VERSION --version $CV
  fi
fi

# Update all CCVs
if [ "$UPDATE_CCVS" = "true" ]
then
  CCV_NAMES=""
  #hammer --csv content-view list --organization-label ${ORG} 
  for CCV_NAME in $(hammer --csv content-view list --organization-label ${ORG} | awk -F"," '$4 ~ /^true$/ { print $2 }') 
  do
    if [ $(hammer content-view info --organization-label ${ORG} --name $CCV_NAME | grep -c $CV) = "1" ]
    then
      #hammer content-view info --organization-label ${ORG} --id $CCV_ID 
      CCV_NAMES="$CCV_NAMES $CCV_NAME" 
    fi
  done
  
  echo Updating the following CCVs: $CCV_NAMES
  echo
  
  for CCV_NAME in $CCV_NAMES
  do
    CCV_ID=$(hammer --csv content-view list --organization-label ${ORG} --name $CCV_NAME | awk -F"," '$4 ~ /^true$/ { print $1 }')
    PUPPET_CV_OLD_VERSION=$(hammer content-view info --id ${CCV_ID} --organization-label $ORG | grep $CV | awk '{ print $NF }')
    PUPPET_CV_OLD_VERSION_ID=$(hammer --csv content-view version list --organization-label $ORG --content-view-id $PUPPET_CV_ID | awk -F, '$3 ~ /^'${PUPPET_CV_OLD_VERSION}'$/ { print $1 }')

    echo Removes old CV version from CCV: $CCV_NAME
    hammer content-view remove-version --organization-label $ORG --content-view-version-id $PUPPET_CV_OLD_VERSION_ID --id ${CCV_ID} 2>&1 > /dev/null

    echo Adding new CV version to CCV: $CCV_NAME
    hammer content-view add-version --organization-label $ORG --content-view-version-id $PUPPET_CV_LATEST_VERSION --id ${CCV_ID} 2>&1 > /dev/null

    echo Publish a new version for the CCV: $CCV_NAME
    hammer content-view publish --id ${CCV_ID} --organization-label $ORG
    CCV_VERSION_ID=$(hammer content-view version list --content-view-id ${CCV_ID} | awk '$0 ~ /Library/ { print $1 }')

    echo Promote a new version of the CCV: $CCV_NAME
    hammer content-view version promote --to-lifecycle-environment-id $LIFECYCLE_ID --organization-label $ORG --content-view-id ${CCV_ID} --id ${CCV_VERSION_ID}
  done
fi

