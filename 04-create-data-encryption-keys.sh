#!/bin/bash

source $(dirname $0)/00-include.sh

printc "\n##############################################\n"
printc "# Gerando EncryptionConfig para criptografia #\n"
printc "##############################################\n"

printc "\n# Gerando chave de criptografia\n"
    ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
	printc "$(echo $ENCRYPTION_KEY)\n" "yellow"

printc "\n# Criando arquivo EncryptionConfig\n"
    cat <<-EOF | sudo tee $PATH_CONFIG/encryption-config.yaml
	kind: EncryptionConfig
	apiVersion: v1
	resources:
	  - resources:
	      - secrets
	    providers:
	      - aescbc:
	          keys:
	            - name: key1
	              secret: ${ENCRYPTION_KEY}
	      - identity: {}
	EOF
    printc "$(ls -1 $PATH_CONFIG/encryption-config.yaml)\n" "yellow"
