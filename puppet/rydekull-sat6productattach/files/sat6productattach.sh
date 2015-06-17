#!/bin/bash
# Take all arguments and act on each of them
#PUPPET_SUPPLIED_PRODUCTS=$@
PRODUCT=$@

# Create a state directory which we can use in puppet
if [ ! -d /root/scripts/.$(basename $0) ]
then
  mkdir -p /root/scripts/.$(basename $0)
fi

#for PRODUCT in $PUPPET_SUPPLIED_PRODUCTS
#do
  # Get the PoolID for each product that is being provided
  POOLID=$(subscription-manager list --available --all | egrep "Subscription Name:|Pool ID:" | sed 'N;s/\n/ /' | awk '$0 ~ /'${PRODUCT}'/ { print $NF }')

  # If PoolID is not empty, attach it
  #if [ "${POOLID}" != "" ] && [ "$(grep -c $PRODUCT /root/scripts/.$(basename $0)/state)" = "1" ]
  if [ "$(awk '$1 ~ /^'${PRODUCT}'$/ { print }' /root/scripts/.$(basename $0)/state)" != "$PRODUCT" ]
  then
    echo subscription-manager attach --pool=${POOLID}
    # Put it into the state file so puppet can find out that its already enabled
    echo $PRODUCT >> /root/scripts/.$(basename $0)/state
  fi
#done
