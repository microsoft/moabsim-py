## Moab Simulator

This project is a simulator for the Moab device. For more information, visit the micro-site at https://aka.ms/moab.

## Building Demo Dockerfile
Clone the bonsai3-py repo locally, and install it. Arrange this repo and bonsai3-py in the following directory structure:
```
./
./bonsai3-py
./samples/moabsim-py/
```

From inside `./samples/moabsim-py/` build the image:
```sh
docker build -t <IMAGE_NAME> -f Dockerfile ../../
```

## Run Dockerfile local
```sh
docker run --rm -it -e SIM_ACCESS_KEY="<your-access-key>" -e SIM_WORKSPACE="<your-workspace>" <IMAGE_NAME>
```


## Microsoft Open Source Code of Conduct
This repository is subject to the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct).
