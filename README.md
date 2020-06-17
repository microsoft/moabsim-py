## Moab Simulator

This project is a simulator for the Moab device. For more information, visit the micro-site at https://aka.ms/moab.

## Building Demo Dockerfile
The following instructions are assuming you are using the bonsai-sdk repo to try out the sample. It will not work without it as it installs the dependencies from that repo.

From inside `./samples/moabsim-py/` build the image:
```sh
docker build -t <IMAGE_NAME> -f Dockerfile ../../
```

## How to push to ACR
```sh
az login  # Is not necessary if you are already up to date or logged in recently
az acr login --subscription <SUBSCRIPTION_ID> --name <ACR_REGISTRY_NAME>
docker tag <IMAGE_NAME> <ACR_REGISTRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>
docker push <ACR_REGSITRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>
```

## Run Dockerfile local
```sh
docker run --rm -it -e SIM_ACCESS_KEY="<your-access-key>" -e SIM_WORKSPACE="<your-workspace>" <IMAGE_NAME>
```


## Microsoft Open Source Code of Conduct
This repository is subject to the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct).
