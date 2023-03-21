Standalone Aurora Relayer and Refiner
=

## Prerequisites and Dependencies
* x64-64 architecture
* requires [Curl]
* requires [Docker] and [Docker-Compose]
* optional [AWS Account], if near datalake on AWS S3 to be used
* depends on [Aurora Relayer2], Web3-compatible relayer server for Aurora
* depends on [Aurora Refiner], allows users to download all NEAR Blocks and get all information relevant to Aurora

## How to Install and Start
```shell
git clone https://github.com/aurora-is-near/standalone-rpc
git checkout {version tag}
cd standalone-rpc
./install.sh
```

Installer configures standalone-rpc, downloads required Near and Aurora snapshots and starts containers to serve RPC 
and sync with blockchain. Depending on your network bandwidth and CPU downloading of snapshots and syncing with the 
chain may take some time. All installation artifacts and chain data are placed under `standalone-rpc/srpc2` directory.

Upon installation, the RPC endpoint is served at http://127.0.0.1:20080/ as well as on the public IPs of your computer.

By default, standalone-rpc installer is configured to work on `mainnet` and near blocks to be consumed from `nearcore`. See installer usage for more details.

```shell
Usage: install.sh [options]
Options
 -n {mainnet|testnet}	network to use, default is mainnet.
 -r {nearcore|datalake}	near source for indexing, default is nearcore.
 -w {number [1-256]}	number of workers used for downloading near snapshots, default is 256.
			NOTE: On some OS and HW configurations, default number of workers may cause high CPU consumption during download.
 -s			if specified then snapshots are ignored during installation, default downloads and uses snapshots.
			NOTE: Ignoring snapshots may cause refiner not to index near chain. This can only be a valid option
			if near source is selected as datalake otherwise refiner will not be sync with near core from scratch.
 -h			prints usage
			
Examples
 ./install.sh -n mainnet -r datalake -s
 AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials ./install.sh -r datalake -s
```

## How to Stop & Start
After installation completes, standalone-rpc should start to serve RPC and catch up with the network. You can always 
**stop** and **start** standalone-rpc by executing the `./stop.sh` or `./start.sh` scripts placed under `srpc2` directory.

## How to Update
The software in this installation is updated automatically. Whenever Aurora releases a new image, it will be downloaded, and services are restarted.

This is however not true for the included database and chain files. These are only downloaded initially when running `./install.sh`. Keep your node running to prevent going out of sync.

## How to Uninstall
```shell
cd standalone-rpc
./uninstall.sh
```

**IMPORTANT** this operation does the followings
* stops and removes Aurora standalone-rpc related docker containers, volumes and networks
* deletes configuration
* asks user for deletion of data, default does not delete


## Write Transactions & Custom Signers
The default installation does not support write transactions. It just sets up a placeholder account and a file for 
further customizations. To enable write transactions with your account, you need to follow the steps below:
* Create an account on testnet/mainnet and load some NEAR on it.
* Export the account's keypair and name into `srpc2/config/relayer/relayer.json` (check the original file for format).
* Change the `signer` value in the `srpc2/config/relayer/relayer.yaml` to the account's name.
* Restart standalone-rpc.

## Good to Know 
* [Aurora Relayer2] configuration can be changed from `srpc2/config/relayer/relayer.yaml`. Some configuration changes can be applied without requiring a restart, please see repository page for more details about configuration.
* standalone-rpc uses [Nginx] as a reverse-proxy before [Aurora Relayer2] RPC endpoints. To change [Nginx] configuration, edit the config file `srpc2/config/nginx/endpoint.conf`, and restart standalone-rpc

[Curl]: https://curl.se/
[Nginx]: https://www.nginx.com/
[Docker]: https://docs.docker.com/engine/install/
[Docker-Compose]: https://docs.docker.com/compose/install/
[AWS Account]: https://youtu.be/GsF7I93K-EQ?t=277
[Aurora Relayer2]: https://github.com/aurora-is-near/relayer2-public
[Aurora Refiner]: https://github.com/aurora-is-near/borealis-engine-lib
