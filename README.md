## Building Demo Dockerfile
docker build -t <IMAGE_NAME> -f Dockerfile ../../

## Run Dockerfile local (optional)
docker run --rm -it -e BONSAI_ACCESS_KEY="<ACCESS_KEY>" -e BONSAI_TARGET="<TARGET>" <IMAGE_NAME>

## How to push to ACR
az login (Is not necessary if you are already up to date or logged in recently)\
az acr login --subscription <SUBSCRIPTION_ID> --name <ACR_REGISTRY_NAME>\
docker tag <IMAGE_NAME> <ACR_REGISTRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>\
docker push <ACR_REGSITRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>


## Example (Assuming you logged in)
docker build -t moab -f Dockerfile ../../\
docker tag moab bonsaisimpreprod.azurecr.io/bonsai/moab\
docker push bonsaisimpreprod.azurecr.io/bonsai/moab\


## Microsoft Open Source Code of Conduct
This repository is subject to the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct).
