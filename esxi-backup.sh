#!/bin/bash

# Basis of this codebase is taken from https://github.com/sixdimensionalarray/esxidown

# User input for the ID of the VM and the path to the VM files
# These details can be obtained from `vim-cmd vmsvc/getallvms`
VMID=$1
VMNAME=$2

source config.cfg
# $ESXIHOST
# $ESXIUSER
# $ESXIPASS
# $BACKUPDIR
# $OVLTOOLPATH
# $DEBUG
# $TRYS
# $WAIT

validate_shutdown()
{
	ssh $ESXIHOST vim-cmd vmsvc/power.getstate $VMID | grep -i "off" > /dev/null 2<&1
	STATUS=$?

	if [ $STATUS -ne 0 ]
	then
		if [ $TRY -lt $TRYS ]
		then
			# If the VM is not off, wait for it to shut down
			TRY=$((TRY + 1))
			echo "Waiting for guest VM $VMNAME ($VMID) to shutdown (attempt #$TRY)..."
			sleep $WAIT
			validate_shutdown
		else
			# Force power off and wait a little (you could use vmsvc/power.suspend here instead)
			echo "Unable to gracefully shutdown guest VM $VMNAME ($VMID)... forcing power off."
			if [ $DEBUG -eq 0 ]
			then
				ssh $ESXIHOST vim-cmd vmsvc/power.off $VMID
			fi
			sleep $WAIT
		fi
	fi
}

TRY=0

ssh $ESXIHOST vim-cmd vmsvc/power.getstate $VMID | grep -i "off" > /dev/null 2<&1
STATUS=$?

if [ $STATUS -ne 0 ]
then
	echo "Attempting shutdown of guest VM $VMNAME ($VMID)..."
	if [ $DEBUG -eq 0 ]
	then
		ssh $ESXIHOST vim-cmd vmsvc/power.shutdown $VMID
	fi
	validate_shutdown
else
	echo "Guest VM $VMNAME ($VMID) already off..."
fi

# Guest is off so ready for backup
echo "Guest VM confirmed to be powered off."
echo "Backing up guest VM $VMNAME ($VMID)..."

$OVLTOOLPATH --overwrite --skipManifestCheck vi://$ESXIUSER:$ESXIPASS@$ESXIHOST/$VMNAME $BACKUPDIR

echo "Backup complete!"
echo ""

echo "Powering guest VM $VMNAME ($VMID) back on..."
ssh $ESXIHOST vim-cmd vmsvc/power.on $VMID
