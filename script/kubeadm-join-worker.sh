#!/bin/bash

sudo chmod 600 ~/.ssh/id_rsa
scp -o StrictHostKeyChecking=no join-worker.sh ubuntu@${each.value.privateip}:/tmp/
ssh -o StrictHostKeyChecking=no ubuntu@${each.value.privateip} 'sudo bash /tmp/join-worker.sh'
