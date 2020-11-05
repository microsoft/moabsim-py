# Intro

Simulators need two environment variables set to be able to attach to the platform.

The first is `SIM_ACCESS_KEY`. You can create one from the `Account Settings` page.
You have one chance to copy the key once it has been created. Make sure you don't enter
the ID.

The second is `SIM_WORKSPACE`. You can find this in the URL after `/workspaces/` once
you are logged in to the platform.

There is also an optional `SIM_API_HOST` key, but if it is not set it will default to `https://api.bons.ai`.

If you're launching your simulator from the command line, make sure that you have these two
environment variables set. If you like, you could use the following example script:

```sh
export SIM_WORKSPACE=<your-workspace-id>
export SIM_ACCESS_KEY=<your-access-key>
python3 moab_sim.py
```

You will need to install support libraries prior to running. Our demos depend on `bonsai-common`.
This library will need to be installed from source.

```sh
pip3 install git+https://github.com/microsoft/bonsai-common
```

## Building Dockerfile

docker build -t <IMAGE_NAME> -f Dockerfile ./

## Run Dockerfile local (optional)

docker run --rm -it -e SIM_ACCESS_KEY="<ACCESS_KEY>" -e SIM_API_HOST="<TARGET>" -e SIM_WORKSPACE="<WORKSPACE>" <IMAGE_NAME>

## How to push to ACR

az login (Is not necessary if you are already up to date or logged in recently)
az acr login --subscription <SUBSCRIPTION_ID> --name <ACR_REGISTRY_NAME>
docker tag <IMAGE_NAME> <ACR_REGISTRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>
docker push <ACR_REGSITRY_NAME>.azurecr.io/bonsai/<IMAGE_NAME>

## Example (Assuming you logged in)

docker build -t moab -f Dockerfile ./
docker tag moab bonsaisimpreprod.azurecr.io/bonsai/moab
docker push bonsaisimpreprod.azurecr.io/bonsai/moab

## Microsoft Open Source Code of Conduct

This repository is subject to the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct).
